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

  # Customizations for RedHat Enterprise Linux and derivatives like
  # CentOS and Amazon Linux.  Specific distros/versions may further
  # override these.
  class RHEL < Component
    include SyncWrap::Distro

    def initialize( opts = {} )
      super
    end

    # Install the specified package names. A trailing hash is
    # interpreted as options, see below.
    #
    # ==== Options
    # :succeed:: Always succeed (useful for local rpm files which
    #            might already be installed.)
    #
    # Other options will be ignored.
    def dist_install( *pkgs )
      opts = pkgs.last.is_a?( Hash ) && pkgs.pop || {}

      if opts[ :succeed ]
        sudo "yum install -q -y #{pkgs.join( ' ' )} || true"
      else
        sudo "yum install -q -y #{pkgs.join( ' ' )}"
      end
    end

    # Uninstall the specified package names.
    def dist_uninstall( *pkgs )
      sudo "yum remove -q -y #{pkgs.join( ' ' )}"
    end

    # Install a System V style init.d service script
    def dist_install_init_service( name )
      sudo "/sbin/chkconfig --add #{name}"
    end

    # Enable the System V style init.d service
    def dist_enable_init_service( name )
      sudo "/sbin/chkconfig #{name} on"
    end

    # Run via sudo, the service command typically supporting 'start',
    # 'stop', 'restart', 'status', etc. arguments.
    def dist_service( *args )
      sudo( [ '/sbin/service', *args ].join( ' ' ) )
    end

  end

end
