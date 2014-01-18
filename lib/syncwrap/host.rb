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

  class Host

    attr_reader :space
    attr_reader :name
    attr_reader :contents

    # FIXME: Short name, long name, or IP?

    def initialize( space, name )
      @space = space
      @name = name
      @contents = [ :all ]
    end

    def add( *args )
      args.each do |arg|
        case( arg )
        when Symbol
          @contents << arg unless @contents.include?( arg )
        when Component
          @contents << arg
        else
          raise "Invalid host #{name} addition: #{c.inspect}"
        end
      end
    end

    def roles
      @contents.select { |c| c.is_a?( Symbol ) }
    end

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

    def component( clz )
      components.reverse.find { |c| c.kind_of?( clz ) }
    end

  end

end
