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
require 'syncwrap/distro'
require 'syncwrap/version_support'
require 'syncwrap/systemd'

module SyncWrap

  # Customizations for \Debian and possibly other deb packaged
  # derivatives. Specific distros/versions may further specialize.
  class Debian < Component
    include Distro
    include VersionSupport
    include SystemD

    # Debian version, i.e. '7.6' No default value.
    attr_accessor :debian_version

    alias :distro_version :debian_version

    protected

    # Set true/false to override the default, distro version based
    # determination of whether systemd is PID 1 on the system.
    attr_writer :systemd

    public

    def initialize( opts = {} )
      super
    end

    def systemd?
      @systemd ||= version_gte?( debian_version, [8] )
    end

    # Install the specified package names. The first time this is
    # applied to any given host, an "apt-get update" is issued as
    # well.  A trailing hash is interpreted as options, see below.
    #
    # ==== Options
    #
    # :check_install:: Short-circuit if all packages already
    #                  installed. Thus no upgrades will be performed.
    #
    # :minimal:: Eqv to --no-install-recommends
    #
    # Additional options are passed to the sudo calls.
    def dist_install( *args )
      opts = args.last.is_a?( Hash ) && args.pop.dup || {}
      args.flatten!
      flags = []
      flags << '--no-install-recommends' if opts.delete( :minimal )
      chk = opts.delete( :check_install ) || opts.delete( :succeed )
      chk = check_install? if chk.nil?
      dist_if_not_installed?( args, chk, opts ) do
        sudo( "apt-get -yqq update", opts ) if first_apt?
        sudo( "apt-get -yq install #{(flags + args).join ' '}", opts )
      end
    end

    # Uninstall the specified package names. A trailing hash is
    # interpreted as options, passed to the sudo calls.
    def dist_uninstall( *pkgs )
      opts = pkgs.last.is_a?( Hash ) && pkgs.pop.dup || {}
      opts.delete( :succeed )
      pkgs.flatten!
      sudo( "apt-get -yq --purge remove #{pkgs.join ' '}", opts )
    end

    # If chk is true, then wrap block in a sudo bash conditional
    # testing if any specified pkgs are not installed. Otherwise just
    # yield to block.
    def dist_if_not_installed?( pkgs, chk, opts, &block )
      if chk
        qry = "dpkg-query -W -f '${db:Status-Status}\\n' #{pkgs.join ' '}"
        cnt = qry + " | grep -c -E '^installed$'"
        cond = %Q{if [ "$(#{cnt})" != "#{pkgs.count}" ]; then}
        sudo( cond, opts.merge( close: 'fi' ), &block )
      else
        block.call
      end
    end

    # Install a System V style init.d service script
    def dist_install_init_service( name )
      sudo "/usr/sbin/update-rc.d #{name} defaults"
    end

    # Enable a service by (short) name either via Debian/System V
    # `update-rc.d` or systemd `systemctl enable`.
    def dist_enable_init_service( name )
      if systemd?
        systemctl( 'enable', dot_service( name ) )
      else
        sudo "/usr/sbin/update-rc.d #{name} enable"
      end
    end

    # Run the service command typically supporting 'start', 'stop',
    # 'restart', 'status', etc. actions.
    # Arguments are in order: shortname, action
    def dist_service( *args )
      if systemd?
        dist_service_via_systemctl( *args )
      else
        sudo( [ '/usr/sbin/service', *args ].join( ' ' ) )
      end
    end

    protected

    def first_apt?
      s = state
      if s[ :debian_apt_updated ]
        false
      else
        s[ :debian_apt_updated ] = true
        true
      end
    end

  end

end
