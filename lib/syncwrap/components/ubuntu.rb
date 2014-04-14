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
require 'syncwrap/distro'

module SyncWrap

  # Customizations for Ubuntu and possibly other Debian/apt packaged
  # derivatives. Specific distros/versions may further specialize.
  class Ubuntu < Component
    include SyncWrap::Distro

    def initialize( opts = {} )
      super
    end

    # Install packages. The first time this is applied to any given
    # host, an "apt-get update" is issued as well.  A trailing hash is
    # interpreted as options, see below.
    #
    # ==== Options
    # :minimal:: Eqv to --no-install-recommends
    def dist_install( *args )
      opts = args.last.is_a?( Hash ) && args.pop || {}
      args.unshift "--no-install-recommends" if opts[ :minimal ]

      sudo( "apt-get -yqq update" ) if first_apt?
      sudo( "apt-get -yq install #{args.join ' '}" )
    end

    def dist_uninstall( *pkgs )
      sudo "aptitude -yq purge #{pkgs.join ' '}"
    end

    def dist_install_init_service( name )
      sudo "/usr/sbin/update-rc.d #{name} defaults"
    end

    def dist_enable_init_service( name )
      sudo "/usr/sbin/update-rc.d #{name} enable"
    end

    def dist_service( *args )
      sudo( [ '/usr/sbin/service', *args ].join( ' ' ) )
    end

    protected

    def first_apt?
      s = state
      if s[ :ubuntu_apt_updated ]
        false
      else
        s[ :ubuntu_apt_updated ] = true
        true
      end
    end

  end

end
