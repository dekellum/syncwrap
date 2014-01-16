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

    def initialize( host )
      @host = host
      reset_queue
      @queue_locked = false
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
    # SyncWrap::Rsync::rsync (see details including options).
    # Any queued commands are flushed beforehand, to avoid ambiguous
    # order of remote changes.
    def rput( *args )
      flush
      rsync( host.name, *args )
    end

    # Capture and return [exit_code, stdout] from command. Does not
    # raise on non-success.  Any commands queued via #sh are flushed
    # beforehand, to avoid ambiguous order of remote changes.
    def capture( command, opts = {} )
      flush
      capture_shell( host.name, command, opts )
    end

    # Enqueue a shell command to be run on host.
    def sh( command, opts = {} )
      opts = opts.dup
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
          run_shell!( host.name, @queued_cmd, @queued_opts )
        ensure
          reset_queue
        end
      end
    end

    private

    def reset_queue
      @queued_cmd = []
      @queued_opts = {}
    end

  end

end
