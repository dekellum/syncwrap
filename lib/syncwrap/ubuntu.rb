#--
# Copyright (c) 2011-2013 David Kellum
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
require 'syncwrap/distro'
require 'thread'

# Customizations for Ubuntu and possibly other Debian/apt packaged
# derivatives. Specific distros/versions may further specialize.
module SyncWrap

  class Ubuntu < Component
    include SyncWrap::Distro

    def initialize( opts = {} )
      @apt_update_state_lock = Mutex.new
      @apt_update_state = {}

      super

      packages_map.merge!( 'apr'       => 'libapr1',
                           'apr-devel' => 'libapr1-dev' )
    end

    # Install packages. The first time this is applied to any given
    # host, an "apt-get update" is issued as well.  A trailing hash is
    # interpreted as options, see below.
    #
    # ==== Options
    # :minimal:: Eqv to --no-install-recommends
    def dist_install( *args )
      opts = args.last.is_a?( Hash ) && args.pop || {}
      args = dist_map_packages( args )
      args.unshift "--no-install-recommends" if opts[ :minimal ]

      sudo( "apt-get -yq update" ) if first_apt?
      sudo( "apt-get -yq install #{args.join ' '}" )
    end

    def first_apt?
      @apt_update_state_lock.synchronize do
        if @apt_update_state[ host ]
          false
        else
          @apt_update_state[ host ] = true
          true
        end
      end
    end

    def dist_uninstall( *pkgs )
      pkgs = dist_map_packages( pkgs )
      sudo "aptitude -yq purge #{pkgs.join ' '}"
    end

    def dist_install_init_service( name )
      sudo "/usr/sbin/update-rc.d #{name} defaults"
    end

    def dist_service( *args )
      sudo( [ '/usr/sbin/service', *args ].join( ' ' ) )
    end

  end

end
