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
require 'syncwrap/version_support'
require 'syncwrap/distro'
require 'syncwrap/systemd'

module SyncWrap

  # Customizations for RedHat Enterprise Linux and base class for
  # derivatives like CentOS and AmazonLinux.
  class RHEL < Component
    include Distro
    include VersionSupport
    include SystemD

    # RHEL version, i.e. '6'. No default value.
    attr_accessor :rhel_version

    alias :distro_version :rhel_version

    def initialize( opts = {} )
      super
    end

    def systemd?
      @is_systemd ||= version_gte?( rhel_version, [7] )
    end

    # Install the specified package names. A trailing hash is
    # interpreted as options, see below.
    #
    # ==== Options
    #
    # :check_install:: Short-circuit if all packages already
    #                  installed. Thus no upgrades will be performed.
    #
    # :succeed:: Deprecated, use check_install instead
    #
    # Additional options are passed to the sudo calls.
    def dist_install( *pkgs )
      opts = pkgs.last.is_a?( Hash ) && pkgs.pop.dup || {}
      opts.delete( :minimal )
      pkgs.flatten!
      chk = opts.delete( :check_install ) || opts.delete( :succeed )
      chk = check_install? if chk.nil?
      dist_if_not_installed?( pkgs, chk, opts ) do
        sudo( "yum install -q -y #{pkgs.join( ' ' )}", opts )
      end
    end

    # Uninstall the specified package names. A trailing hash is
    # interpreted as options, see below.
    #
    # ==== Options
    #
    # :succeed:: Succeed even if none of the packages are
    #            installed. (Deprecated, Default: true)
    #
    # Additional options are passed to the sudo calls.
    def dist_uninstall( *pkgs )
      opts = pkgs.last.is_a?( Hash ) && pkgs.pop.dup || {}
      pkgs.flatten!
      if opts.delete( :succeed ) != false
        sudo( <<-SH, opts )
          if yum list -C -q installed #{pkgs.join( ' ' )} >/dev/null 2>&1; then
            yum remove -q -y #{pkgs.join( ' ' )}
          fi
        SH
      else
        sudo( "yum remove -q -y #{pkgs.join( ' ' )}", opts )
      end
    end

    # If chk is true, then wrap block in a sudo bash conditional
    # testing if any specified pkgs are not installed. Otherwise just
    # yield to block.
    def dist_if_not_installed?( pkgs, chk, opts, &block )
      if chk
        qry = "yum list -C -q installed #{pkgs.join ' '}"
        cnt = qry + " | tail -n +2 | wc -l"
        cond = %Q{if [ "$(#{cnt})" != "#{pkgs.count}" ]; then}
        sudo( cond, opts.merge( close: 'fi' ), &block )
      else
        block.call
      end
    end

    # Install a System V style init.d service script
    def dist_install_init_service( name )
      sudo "/sbin/chkconfig --add #{name}"
    end

    # Enable a service by (short) name either via RHEL/System V
    # `chkconfig on` or systemd `systemctl enable`.
    def dist_enable_init_service( name )
      if systemd?
        systemctl( 'enable', dot_service( name ) )
      else
        sudo "/sbin/chkconfig #{name} on"
      end
    end

    # Run the service command typically supporting 'start', 'stop',
    # 'restart', 'status', etc. actions.
    # Arguments are in order: shortname, action
    def dist_service( *args )
      if systemd?
        dist_service_via_systemctl( *args )
      else
        sudo( [ '/sbin/service', *args ].join( ' ' ) )
      end
    end

  end

end
