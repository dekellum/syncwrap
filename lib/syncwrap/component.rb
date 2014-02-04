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
      sh( command, { user: :root }.merge( opts ), &block )
    end

    # Equivalent to sh( command, user: run_user ) where run_user would
    # typically come from the RunUser component.
    def rudo( command, opts = {}, &block )
      sh( command, { user: run_user }.merge( opts ), &block )
    end

    # FIXME: rdoc
    def rput( *args )
      opts = args.last.is_a?( Hash ) && args.pop || {}
      opts = opts.dup
      opts[ :erb_binding ] = custom_binding( opts[ :erb_vars ] || {} )
      ctx.rput( *args, opts )
    end

    # Returns the path to the the specified src, first found in
    # :src_roots option.  Returns nil if not found.
    def find_source( src, opts = {} )
      ctx.find_source( src, opts )
    end

    def flush
      ctx.flush
    end

    # Dynamically send missing methods to in-context, same host
    # Components, that were added before self (lower in the stack).
    def method_missing( meth, *args, &block )
      ctx = Context.current

      # Guard and no-op if reentrant or calling out of context.
      if ctx && mm_lock
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

    def mm_lock
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

    def custom_binding( extra_vars = {} )
      extra_vars.inject( clean_binding ) do |b,(k,v)|
        ks = k.to_sym.to_s
        # Can't yet rely on ruby 2.1 Binding#local_variable_set, so
        # use this eval trick instead, to be able to set arbitrary value
        # types.
        b.eval("#{ks}=nil; lambda { |v| #{ks}=v }").call(v)
        b
      end
    end

    def clean_binding
      Kernel.binding
    end

  end

end
