#--
# Copyright (c) 2011-2015 David Kellum
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
  # Host component dependencies: <ruby>
  #
  class BundlerGem < Component

    # Bundler version to install (Default: 1.6.5)
    attr_accessor :bundler_version

    def initialize( opts = {} )
      @bundler_version = '1.6.5'
      super
    end

    def bundle_command
      ( ruby_command == 'jruby' ) ? 'jbundle' : 'bundle'
    end

    def install
      opts = { version: bundler_version }
      opts[ :format_executable ] = true unless bundle_command == 'bundle'
      gem_install( 'bundler', opts )
    end

  end

end
