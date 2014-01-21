#--
# Copyright (c) 2011-2014 David Kellum
#
# Licensed under the Apache License, Version 2.0 (the "License"); you
# may not use this file except in compliance with the License.  You
# may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.  See the License for the specific language governing
# permissions and limitations under the License.
#++

require 'syncwrap/shell'
require 'syncwrap/rsync'
require 'term/ansicolor'

module SyncWrap

  class Context
    include Shell
    include Rsync

    class << self
      def current
        Thread.current[:syncwrap_context]
      end

      def swap( ctx )
        old = current
        Thread.current[:syncwrap_context] = ctx
        old
      end
    end

    attr_reader :host

    def initialize( host, opts = {} )
      @host = host
      reset_queue
      @queue_locked = false
      @default_opts = opts

      super()
    end

    def with
      prior = Context.swap( self )
      yield
      flush
    ensure
      Context.swap( prior )
    end

    # Put files or entire directories to host via
    # SyncWrap::Rsync::rsync (see details including options).  Any
    # commands queued via #sh are flushed beforehand, to avoid
    # ambiguous order of remote changes.
    def rput( *args )
      opts = @default_opts.merge( coalesce: false )
      opts = opts.merge( args.pop ) if args.last.is_a?( Hash )

      flush
      args = rsync_args( ssh_host_name, *args, opts )
      exit_code, outputs = capture_stream( args, host, :rsync, opts )

      # Return array of --itemize-changes on standard out.
      collect_stream( :out, outputs ).
        split( "\n" ).
        map { |l| l =~ /^(\S{11})\s(.+)$/ && [$1, $2] }. #itemize-changes
        compact
    end

    # Capture and return [exit_code, stdout] from command. Does not
    # raise on non-success.  Any commands queued via #sh are flushed
    # beforehand, to avoid ambiguous order of remote changes.
    def capture( command, opts = {} )
      opts = @default_opts.merge( coalesce: false, dryrun: false ).merge( opts )
      flush
      capture_shell( command, opts )
    end

    # Return true if being executed in dryrun mode.
    def dryrun?
      @default_opts[ :dryrun ]
    end

    # Enqueue a shell command to be run on host.
    def sh( command, opts = {} )
      opts = @default_opts.merge( opts )
      close = opts.delete( :close )

      flush if opts != @queued_opts #may still be a no-op

      @queued_cmd << command
      @queued_opts = opts

      if close
        prev, @queue_locked = @queue_locked, true
      end

      begin
        yield if block_given?
        @queued_cmd << close if close
      ensure
        @queue_locked = prev if close
      end
    end

    def flush
      if @queued_cmd.length > 0
        begin
          if @queue_locked
            raise NestingError, 'Queue at flush: ' + @queued_cmd.join( '\n' )
          end
          run_shell!( @queued_cmd, @queued_opts )
        ensure
          reset_queue
        end
      end
    end

    private

    def ssh_host_name
      host.space.ssh_host_name( host )
    end

    def reset_queue
      @queued_cmd = []
      @queued_opts = {}
    end

    def run_shell!( command, opts = {} )
      args = ssh_args( ssh_host_name, command, opts )
      capture_stream( args, host, :sh, opts )
    end

    def capture_shell( command, opts = {} )
      args = ssh_args( ssh_host_name, command, opts )
      exit_code, outputs = capture_stream( args, host, :capture, opts )
      [ exit_code, collect_stream( opts[ :coalesce ] ? :err : :out, outputs ) ]
    end

    def capture_stream( args, host, mode, opts )
      if mode == :capture
        accept = opts[:accept]
        success = "accepted"
      else
        accept = [ 0 ]
        success = "success"
      end

      # When :verbose -> nil -> try_lock
      stream_output = opts[ :verbose ] ? nil : false
      fmt = host.space.formatter
      do_color = !opts[ :coalesce ]

      begin
        exit_code, outputs = capture3( args ) do |stream, chunk|
          if stream_output.nil?
            if fmt.lock.try_lock
              stream_output = true
              fmt.write_header( host, mode, opts, :stream )
              if mode == :rsync
                fmt.write_command_output( :cmd,
                                          args.join(' ') + "\n", do_color )
              end
            else
              stream_output = false
            end
          end

          if stream_output
            fmt.write_command_output( stream, chunk, do_color )
            fmt.flush
          end
        end
        failed = accept && !accept.include?( exit_code )

        if stream_output
          fmt.output_terminate
          fmt.write_result( "Exit #{exit_code} (#{success})" ) unless failed
        end
      ensure
        fmt.lock.unlock if stream_output
      end

      if !stream_output && ( failed || opts[ :verbose ] )
        fmt.sync do
          fmt.write_header( host, mode, opts )
          if mode == :rsync
            fmt.write_command_output( :cmd, args.join(' ') + "\n", do_color )
          end
          fmt.write_command_outputs( outputs, do_color )
          fmt.write_result( "Exit #{exit_code} (#{success})" ) unless failed
        end
      end

      raise CommandFailure, "#{args[0]} exit code: #{exit_code}" if failed
      [ exit_code, outputs ]
    end

  end

end
