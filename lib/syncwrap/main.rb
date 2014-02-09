#--
# Copyright (c) 2011-2014 David Kellum
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
#++

require 'syncwrap'

module SyncWrap

  # A limited set of (private) methods for use at the top-level in
  # a sync.rb. All of these methods delegate to the _current_
  # Space.
  module Main

    private

    # The current Space
    def space # :doc:
      Space.current
    end

    # Shorthand for space.role
    def role( *args ) # :doc:
      space.role( *args )
    end

    # Shorthand for host.role
    def host( *args ) # :doc:
      space.host( *args )
    end

    # Merge options given, or (without opts) return space.default_options
    def options( opts = nil ) # :doc:
      if opts
        space.merge_default_options( opts )
      else
        space.default_options
      end
    end

  end

end

# Extend the top level Object with the Main module
self.extend SyncWrap::Main
