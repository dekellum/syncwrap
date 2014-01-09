#--
# Copyright (c) 2011-2013 David Kellum
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
# The non-blocking implementation of capture below was derived from
# rake-remote_task, MIT License:
# Copyright (c) Ryan Davis, RubyHitSquad
#++

require 'syncwrap/base'
require 'open3'

# Common utility methods and variables.
module SyncWrap::Shell

  def initialize
    super
  end

  # Local:
  # sh -v -e -c STRING
  # sudo SUDOFLAGS [-u user] sh [-v -e -n] -c STRING
  #
  # Remote:
  # ssh SSHFLAGS host sh [-v -e -n] -c STRING
  # ssh SSHFLAGS host sudo SUDOFLAGS [-u user] sh [-v -e -n] -c STRING

  # typical SSHFLAGS: -i ./key.pem -l ec2-user
  # typical SUDOFLAGS: -H

  def run( host, command, opts = {} )
    args = ssh_args( host, command, opts )
    exit_code, outputs = capture( args )
    if exit_code != 0 || opts[ :verbose ]
      #Output verbose
    end
  end

  def ssh_args( host, command, opts = {} )
    args = []
    if host != 'localhost'
      args = [ 'ssh' ]
      args += opts[ :ssh_flags ] if opts[ :ssh_flags ]
      args << host.to_s
    end
    args + sudo_args( command, opts )
  end

  def sudo_args( command, opts = {} )
    args = []
    if opts[ :user ]
      args = [ 'sudo' ]
      args += opts[ :sudo_flags ] if opts[ :sudo_flags ]
      args += [ '-u', opts[ :user ] ] unless opts[ :user ] == :root
      #FIXME: Also handle special :runr?
    end
    args + sh_args( command, opts )
  end

  def sh_args( command, opts = {} )
    args = [ 'sh' ]
    args << '-e' if opts[ :error ].nil? || opts[ :error ] == :exit
    args << '-v' unless opts[ :verbose ] == false
    args << '-n' if opts[ :dryrun  ]
    args + [ '-c', args_to_command( command ) ]
  end

  def args_to_command( args )
    Array( args ).flatten.compact
      .map { |arg| arg.split( $/ ) }
      .flatten
      .map { |l| l.strip }
      .reject { |l| l.empty? }
      .join( "\n" )
  end

  def capture( args )
    status = nil
    outputs = []
    Open3::popen3( *args ) do |inp, out, err, wait_thread|
      inp.sync = true

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

          yield( marker, chunk, inp ) if block_given?

          # Merge chunks from the same stream
          l = outputs.last
          if l && l[0] == marker
            l[1] << chunk
          else
            outputs << [ marker, chunk ]
          end

        end
      end

      inp.close rescue nil

      # Older jruby (even in 1.9+ mode) doesn't provide wait_thread but
      # does return the status in $? instead (see workaround below)
      status = wait_thread.value if wait_thread
    end

    status ||= $?

    [ status && status.exitstatus, outputs ]
  end

end