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

require 'syncwrap/context'

module SyncWrap

  class Component
    def initialize( opts = {} )
      super()
      opts.each do |name,val|
        send( name.to_s + '=', val )
      end
    end

    def host
      ctx.host
    end

    def capture( command, opts = {} )
      ctx.capture( command, opts )
    end

    def dryrun?
      ctx.dryrun?
    end

    # FIXME: rdoc
    def sh( command, opts = {}, &block )
      ctx.sh( command, opts, &block )
    end

    # Equivalent to sh( command, user: :root )
    def sudo( command, opts = {}, &block )
      sh( command, opts.merge( user: :root ), &block )
    end

    # Equivalent to sh( command, user: run_user ) where run_user would
    # typically come from the RunUser component.
    def rudo( command, opts = {}, &block )
      sh( command, opts.merge( user: run_user ), &block )
    end

    # FIXME: rdoc
    def rput( *args )
      ctx.rput( *args )
    end

    def flush
      ctx.flush
    end

    # Dynamically send missing methods to in-context, same host
    # Components, that were added before self (lower in the stack).
    def method_missing( meth, *args, &block )
      ctx = Context.current

      # Guard and no-op if reentrant or calling out of context.
      if ctx && mm_lock?
        begin
          unlocked = false
          below = false
          ctx.host.components.reverse_each do |comp|
            if comp == self
              below = true
            elsif below
              if comp.respond_to?( meth )
                unlocked = mm_unlock
                return comp.send( meth, *args, &block )
              end
            end
          end
        ensure
          mm_unlock unless unlocked
        end
      end

      super
    end

    private

    def ctx
      Context.current or raise "ctx called out of SyncWrap::Context"
    end

    def mm_lock?
      if Thread.current[:syncwrap_component_mm]
        false
      else
        Thread.current[:syncwrap_component_mm] = true
        true
      end
    end

    def mm_unlock
      Thread.current[:syncwrap_component_mm] = false
      true
    end

  end

end
