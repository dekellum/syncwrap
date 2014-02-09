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

module SyncWrap

  # Represents various host (server, machine instance) metadata and
  # serves as a container for #roles and #components.
  class Host

    # The space in which this host was constructed.
    attr_reader :space

    # Array of role Symbols or (direct) Component instances in the
    # order added.
    attr_reader :contents

    def initialize( space, props = {} )
      @space = space
      @props = {}
      merge_props( props )
      @contents = [ :all ]
    end

    # Return the :name property.
    def name
      self[ :name ]
    end

    # Return the property by (Symbol) key
    def []( key )
      @props[ key ]
    end

    # Set property by (Symbol) key to value. Note that the :roles
    # property key is supported here, but is effectively the same as
    # #add( val ). Roles are only added, never removed.
    def []=( key, val )
      key = key.to_sym
      if key == :roles
        add( *val )
      else
        @props[ key.to_sym ] = val
      end
      val
    end

    # Merge properties. Note that the :roles property key is
    # supported here, but is affectively the same as #add( val ).
    def merge_props( opts )
      opts.each do |key,val|
        self[ key ] = val
      end
    end

    def to_h
      @props.merge( roles: roles )
    end

    # Add any number of roles (by Symbol) or (direct) Component
    # instances.
    def add( *args )
      args.each do |arg|
        case( arg )
        when Symbol
          @contents << arg unless @contents.include?( arg )
        when Component
          @contents << arg
        else
          raise "Invalid host #{name} addition: #{arg.inspect}"
        end
      end
    end

    # Return an Array of previously added role symbols.
    def roles
      @contents.select { |c| c.is_a?( Symbol ) }
    end

    # Return a flat Array of Component instances by traversing
    # previously added roles and any direct components in order.
    def components
      @contents.inject([]) do |m,c|
        if c.is_a?( Symbol )
          m += space.role( c )
        else
          m << c
        end
        m
      end
    end

    # Return the last component added to this Host prior to the given
    # component (either directly or via a role), or nil if there is no
    # such component.
    def prior_component( component )
      last = nil
      @contents.each do |c|
        if c.is_a?( Symbol )
          space.role( c ).each do |rc|
            return last if rc.equal?( component ) #identity
            last = rc
          end
        else
          return last if c.equal?( component ) #identity
          last = c
        end
      end
      nil
    end

    # Return the _last_ component which is a kind of the specified
    # Class or Module clz, or nil if not found.
    def component( clz )
      components.reverse.find { |c| c.kind_of?( clz ) }
    end

  end

end
