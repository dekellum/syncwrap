#--
# Copyright (c) 2011-2016 David Kellum
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

module SyncWrap

  # Support module for components which listen for and act on changes
  # set on SyncWrap::Context#state keys.
  module ChangeKeyListener

    protected

    def initialize( opts = {} )
      @change_key = nil
      super
    end

    # An optional state key, or array of state keys, to check for
    # changes.  (Default: nil; Example: :source_tree)
    attr_accessor :change_key

    # Returns true if there are any changes with any #change_key.
    def change_key_changes?
      Array( change_key ).any? do |k|
        c = state[ k ]
        c && !c.emtpy?
      end
    end

    # Returns the combined array of all changes on all #change_key.
    def change_key_changes
      Array( change_key ).inject( [] ) do |m,k|
        c = state[ k ]
        if c
          m + c
        else
          m
        end
      end
    end

  end

end
