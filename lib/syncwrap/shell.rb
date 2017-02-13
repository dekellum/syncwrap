#--
# Copyright (c) 2011-2017 David Kellum
#
# Licensed under the Apache License, Version 2.0 (the "License"); you
# may not use this file except in compliance with the License.  You may
# obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.  See the License for the specific language governing
# permissions and limitations under the License.
#
# The non-blocking aspects of Shell::capture3 below were partially
# derived from rake-remote_task, released under MIT License:
# Copyright (c) Ryan Davis, RubyHitSquad
#++

require 'open3'

module SyncWrap

  # Low level command construction and process output capture.
  #
  # == Supported Command Forms
  #
  #   LOCAL:
  #   bash BASH_FLAGS -c COMMANDS
  #   sudo SUDO_FLAGS bash BASH_FLAGS -c COMMANDS
  #
  #   REMOTE:
  #   ssh SSH_FLAGS HOST bash BASH_FLAGS -c "COMMANDS" [1>&2]
  #   ssh SSH_FLAGS HOST sudo SUDO_FLAGS bash BASH_FLAGS -c "COMMANDS" [1>&2]
  #
  #   BASH_FLAGS: [-v|-x] [-e] [-o pipefail] [-n]
  #   SUDO_FLAGS: [-u :user] :sudo_flags ...
  #   SSH_FLAGS:  [-l :ssh_user] [-i :ssh_user_pem] :ssh_flags ...
  #
  module Shell

    private

    # When host is not 'localhost' return ssh command, flags,
    # arguments on top of #sudo_args. Otherwise pass through to
    # #sudo_args.
    def ssh_args( host, command, opts = {} ) # :doc:
      args = []
      if host != 'localhost'
        opts = opts.dup
        coalesce = opts.delete( :coalesce )
        args = [ 'ssh' ]
        args += opts[ :ssh_flags ] if opts[ :ssh_flags ]
        if opts[ :ssh_options ]
          args += opts[ :ssh_options ].map { |o| [ '-o', o.join('=') ] }.flatten
        end
        if opts[ :ssh_user ]
          args += [ '-l', opts[ :ssh_user ] ]
          args += [ '-i', opts[ :ssh_user_pem ] ] if opts[ :ssh_user_pem ]
        end
        args << host.to_s
        sargs = sudo_args( command, opts )
        cmd = sargs.pop
        args += sargs
        args << ( '"' + shell_escape_cmd( cmd ) + '"' )
        args << '1>&2' if coalesce
        args
      else
        sudo_args( command, opts )
      end
    end

    # Return sudo command, flags, arguments on top of #sh_args if the
    # :user option is specified. Otherwise pass through to #sh_args.
    def sudo_args( command, opts = {} ) # :doc:
      args = []
      if opts[ :user ]
        args = [ 'sudo' ]
        args += opts[ :sudo_flags ] if opts[ :sudo_flags ]
        # FIXME: Replace with :sudo_home support for '-H'?
        args += [ '-u', opts[ :user ] ] unless opts[ :user ] == :root
      end
      args + sh_args( command, opts )
    end

    # Return bash command, flags, arguments for the given command(s)
    # passed to #commmand_lines_cleanup.
    def sh_args( command, opts = {} ) # :doc:
      args = [ 'bash' ]
      if opts[ :error ].nil? || opts[ :error ]
        args << '-e'
        args += %w[ -o pipefail ] unless opts[ :pipefail ] == false
      else
        args += %w[ -o pipefail ] if opts[ :pipefail ]
      end
      args << '-n' if opts[ :dryrun ]

      if opts[ :coalesce ]
        args << '-c'
        cmd = String.new( "exec 1>&2\n" )
        if opts[ :sh_verbose ]
          cmd << "set " << ( opts[ :sh_verbose ] == :x ? '-x' : '-v' ) << "\n"
        end
        cmd << "cd /\n" if opts[:user]
        cmd << command_lines_cleanup( command )
        args << cmd
      else
        if opts[ :sh_verbose ]
          args << ( opts[ :sh_verbose ] == :x ? '-x' : '-v' )
        end
        args << '-c'
        cmd = String.new
        cmd << "cd /\n" if opts[:user]
        cmd << command_lines_cleanup( command )
        args << cmd
      end
      args
    end

    # Escape the provided cmd string for inclusion in a bash quoted
    # string command.  This is only needed when using ssh.
    def shell_escape_cmd( cmd ) # :doc:
      cmd.gsub( /["$`\\]/ ) { |c| '\\' + c }
    end

    # Given one or an Array of commands, apply #block_trim_padding to
    # each and join all with newlines.
    def command_lines_cleanup( commands ) # :doc:
      Array( commands )
        .map { |cmd| block_trim_padding( cmd.split( $/ ) ) }
        .flatten
        .join( "\n" )
    end

    # Left strip lines, but preserve increased indentation in
    # subsequent lines. Also right strip and drop blank lines
    def block_trim_padding( lines ) # :doc:
      pad = nil
      lines
        .reject { |l| l =~ /^\s*$/ } #blank lines
        .map do |line|
        line = line.dup
        unless pad && line.gsub!(/^(\s{,#{pad}})/, '')
          prior = line.length
          line.gsub!(/^(\s*)/, '')
          pad = prior - line.length
        end
        line.rstrip!
        line
      end
    end

    # Captures out and err from a command expressed by args
    # array. Returns [ exit_status, [outputs] ] where [outputs] is an
    # array of [:err|:out, buffer] elements. Uses select, non-blocking
    # I/O to receive buffers in the order they become available. This
    # is often the same order you would see them in a real interactive
    # terminal, but not always, as buffering or timing issues in the
    # underlying implementation may cause some out of order results.
    def capture3( args ) # :doc:
      status = nil
      outputs = []
      Open3::popen3( *args ) do |inp, out, err, wait_thread|
        inp.close rescue nil

        streams = [ err, out ]

        until streams.empty? do
          selected, = select( streams, nil, nil, 0.1 )
          next if selected.nil? || selected.empty?

          selected.each do |stream|
            if stream.eof?
              streams.delete( stream )
              next
            end

            chunk = stream.readpartial( 8192 )
            marker = (stream == out) ? :out : :err

            yield( marker, chunk ) if block_given?

            # Merge chunks from the same stream
            l = outputs.last
            if l && l[0] == marker
              l[1] += chunk
            else
              outputs << [ marker, chunk ]
            end

          end
        end

        # Older jruby (even in 1.9+ mode) doesn't provide wait_thread but
        # does return the status in $? instead (see workaround below)
        status = wait_thread.value if wait_thread
      end

      #FIXME: Only if jruby?
      status ||= $?

      [ status && status.exitstatus, outputs ]
    end

    # Select and merge the output buffers of the specific stream from
    # outputs (as returned by #capture3)
    def collect_stream( stream, outputs ) # :doc:
      outputs.
        select { |o| o[0] == stream }.
        map { |o| o[1] }. #the buffers
        inject( "", :+ )
    end

  end

end
