#--
# Copyright (c) 2011-2017 David Kellum
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

  # Provision for the rake rubygem and its (j)rake command
  #
  # Host component dependencies: <Ruby>
  #
  class RakeGem < Component

    # Rake version to install (Default: 10.3.2)
    attr_accessor :rake_version

    def initialize( opts = {} )
      @rake_version = '10.3.2'
      super
    end

    def rake_command
      ( ruby_command == 'jruby' ) ? 'jrake' : 'rake'
    end

    def install
      opts = { version: rake_version }
      opts[ :format_executable ] = true unless rake_command == 'rake'
      gem_install( 'rake', opts )
    end

  end
end
