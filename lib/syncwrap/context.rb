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

module SyncWrap

  # A single-thread execution context for a single Host.
  #
  # Context implements much of the interface and behavior defined by
  # Component, via use of the Shell and Rsync module mixins.
  class Context
    include Shell
    include Rsync

    class << self
      # Return the current (thread local) Context, or nil.
      def current
        Thread.current[:syncwrap_context]
      end

      # Set the current Context to ctx and return any prior Context or
      # nil.
      def swap( ctx )
        old = current
        Thread.current[:syncwrap_context] = ctx
        old
      end
    end

    # The current Host of this context
    attr_reader :host

    # A Hash-like interface of keys/values backed read-only by the
    # host properties.
    attr_reader :state

    # Construct given host and default_options to use for all #sh and
    # #rput calls.
    def initialize( host, opts = {} )
      @host = host
      @state = StateHash.new( host )
      reset_queue
      @queue_locked = false
      @default_options = opts

      super()
    end

    # Set (thread local) current context to self, yield to block, then
    # #flush and reset the context.
    def with
      prior = Context.swap( self )
      yield
      flush
    ensure
      Context.swap( prior )
    end

    # Return true if being executed, by constructed default options,
    # in dryrun mode.
    def dryrun?
      @default_options[ :dryrun ]
    end

    # Return true if :verbose is set in constructed default options.
    def verbose?
      @default_options[ :verbose ]
    end

    # See Component#sh for interface details
    def sh( command, opts = {} )
      opts = @default_options.merge( opts )
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
      nil
    end

    # See Component#flush for interface details
    def flush
      if @queued_cmd.length > 0
        begin
          if @queue_locked
            raise NestingError, 'Queue at flush: ' + @queued_cmd.join( '\n' )
          end
          run_shell( @queued_cmd, @queued_opts )
        ensure
          reset_queue
        end
      end
      nil
    end

    # See Component#capture for interface details.
    def capture( command, opts = {} )
      opts = @default_options.merge( coalesce: false, dryrun: false ).merge( opts )
      flush
      capture_shell( command, opts )
    end

    # See Component#rput for interface details.
    def rput( *args )
      opts = @default_options
      opts = opts.merge( args.pop ) if args.last.is_a?( Hash )
      opts = opts.merge( coalesce: false )

      flush

      srcs, target = expand_implied_target( args )

      srcs = resolve_sources( srcs, Array( opts[ :sync_paths ] ) )

      changes = []

      if opts[:erb_process] != false
        sdirs, sfiles =   srcs.partition { |src| File.directory?( src ) }
        serbs, sfiles = sfiles.partition { |src| src =~ /\.erb$/ }
        plains = sdirs + sfiles #might not have/is not templates
        maybes = sdirs + serbs  #might have/is templates

        if maybes.empty?
          changes = rsync( plains, target, opts ) unless plains.empty?
        else
          process_templates( maybes, opts ) do |processed|
            unless processed.empty? || plains.empty?
              opts = opts.dup
              opts[ :excludes ] = Array( opts[ :excludes ] ) + [ '*.erb' ]
            end
            new_srcs = plains + processed
            changes = rsync( new_srcs, target, opts ) unless new_srcs.empty?
          end
        end
      else
        changes = rsync( srcs, target, opts ) unless srcs.empty?
      end

      changes
    end

    # Returns the path to the the specified src, first found in
    # :sync_paths option.  Returns nil if not found.
    def find_source( src, opts = {} )
      opts = @default_options.merge( opts )
      resolve_source( src, Array( opts[ :sync_paths ] ) )
    end

    private

    def ssh_host_name
      host.space.ssh_host_name( host )
    end

    def reset_queue
      @queued_cmd = []
      @queued_opts = {}
    end

    def run_shell( command, opts = {} )
      args = ssh_args( ssh_host_name, command, opts )
      capture_stream( args, host, :sh, opts )
    end

    def capture_shell( command, opts = {} )
      args = ssh_args( ssh_host_name, command, opts )
      exit_code, outputs = capture_stream( args, host, :capture, opts )
      [ exit_code, collect_stream( opts[ :coalesce ] ? :err : :out, outputs ) ]
    end

    def rsync( srcs, target, opts )
      args = rsync_args( ssh_host_name, srcs, target, opts )
      exit_code, outputs = capture_stream( args, host, :rsync, opts )

      # Return array of --itemize-changes on standard out.
      collect_stream( :out, outputs ).
        split( "\n" ).
        map { |l| l =~ /^(\S{11})\s(.+)$/ && [$1, $2] }. #itemize-changes
        compact
    end

    def capture_stream( args, host, mode, opts )
      accept = opts[ :accept ] || [ 0 ]
      success_msg = ( accept == [ 0 ] ) ? "success" : "accepted"

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
                cmd = args.join(' ') + "\n"
                fmt.write_command_output( :cmd, cmd, do_color )
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
        failed = !accept.include?( exit_code )

        if stream_output
          fmt.output_terminate
          fmt.write_result( "Exit #{exit_code} (#{success_msg})" ) unless failed
        end
      ensure
        fmt.lock.unlock if stream_output
      end

      if !stream_output &&
          ( failed || opts[ :verbose ] ||
            ( opts[ :verbose_changes ] && !outputs.empty? && mode == :rsync ) )
        fmt.sync do
          fmt.write_header( host, mode, opts )
          if mode == :rsync
            fmt.write_command_output( :cmd, args.join(' ') + "\n", do_color )
          end
          fmt.write_command_outputs( outputs, do_color )
          fmt.write_result( "Exit #{exit_code} (#{success_msg})" ) unless failed
        end
      end

      raise CommandFailure, "#{args[0]} exit code: #{exit_code}" if failed
      [ exit_code, outputs ]
    end

  end

  # The Context#state Hash-like implementation, backed read-only by
  # the associated host properties.
  class StateHash
    def initialize( host )
      @host = host
      @props = {}
    end

    def []( key )
      @props[ key ] || @host[ key ]
    end

    def []=( key, val )
      @props[ key.to_sym ] = val
    end
  end

end
