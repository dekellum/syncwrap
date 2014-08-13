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

require 'syncwrap/component'

require 'syncwrap/git_help'
require 'syncwrap/path_util'

module SyncWrap

  # Provision to `bundle install`, optionally triggered by a state change key.
  #
  # Host component dependencies: RunUser, BundlerGem
  #
  class Bundle < Component
    include PathUtil

    # An optional state key to check, indicating changes requiring
    # bundle install (Default: nil; Example: :source_tree)
    attr_accessor :change_key
    protected :change_key, :change_key=

    # Path to the Gemfile(.lock)
    # (Default: SourceTree#remote_source_path)
    attr_writer :bundle_path

    def bundle_path
      @bundle_path || remote_source_path
    end

    def initialize( opts = {} )
      @change_key = nil
      @bundle_path = nil
      super
    end

    def install
      bundle_install if change_key.nil? || state[ change_key ]
    end

    def bundle_install
      rudo( "( cd #{bundle_path}", close: ')' ) do
        rudo( "#{bundle_command} #{bundler_version} " +
              "install --path ~/.gem --binstubs ./bin" )
      end
    end

  end
end
