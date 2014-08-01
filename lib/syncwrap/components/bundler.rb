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

module SyncWrap

  # Provision for the bundler rubygem and its (j)bundle command
  #
  # Host component dependencies: <Ruby>
  #
  class Bundler < Component

    # Bundler version to install (Default: 1.6.5)
    attr_accessor :bundler_version

    def initialize( opts = {} )
      @bundler_version = '1.6.5'
      super
    end

    def install
      sudo( "if ! hash #{bundle_command} 2>/dev/null; then", close: 'fi' ) do
        gem_install_bundler
      end
    end

    def gem_install_bundler
      args = [ 'bundler' ]
      args.unshift( '--format-executable' ) if bundle_command == 'jbundle'
      gem_install( args, version: bundler_version )
    end

    def bundle_command
      ( gem_command == 'jgem' ) ? 'jbundle' : 'bundle'
    end

  end
end
