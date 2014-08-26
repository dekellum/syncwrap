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

  # Provision for the rjack-tarpit rubygem
  #
  # Host component dependencies: RunUser?, <ruby>
  #
  class TarpitGem < Component

    # Tarpit version to install (Default: 1.1.0)
    attr_accessor :tarpit_version

    protected

    # Perform a user_install as the run_user? (Default: false)
    attr_writer :user_install

    def user_install?
      @user_install
    end

    public

    def initialize( opts = {} )
      @tarpit_version = '2.1.0'
      @user_install = false
      super
    end

    def install
      opts = { version: tarpit_version, user_install: user_install? && run_user }

      # tarpit depends on rake, etc., so use format_executable even
      # though tarpit doesn't have any bin scripts
      opts[ :format_executable ] = true if ruby_command == 'jruby'

      gem_install( 'rjack-tarpit', opts )
    end

  end

end
