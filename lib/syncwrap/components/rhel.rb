#--
# Copyright (c) 2011-2016 David Kellum
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

    protected

    # Set true/false to override the default, distro version based
    # determination of whether systemd is PID 1 on the system.
    attr_writer :systemd

    public

    def initialize( opts = {} )
      super
    end

    def systemd?
      if @systemd.nil?
        @systemd = version_gte?( rhel_version, [7] )
      end
      @systemd
    end

    # Install the specified packages. When rpm HTTP URLs or local file
    # paths are given instead of package names, these are installed
    # first and individually via #dist_install_url. Calling that
    # explicitly may be preferable. A trailing hash is interpreted as
    # options, see below.
    #
    # ==== Options
    #
    # :check_install:: Short-circuit if packages are already
    #                  installed, and thus don't perform updates
    #                  unless versions are specified. (Default: true)
    #
    # :yum_flags:: Additional array of flags to pass to `yum install`.
    #
    # Options are also passed to the sudo calls.
    def dist_install( *pkgs )
      opts = pkgs.last.is_a?( Hash ) && pkgs.pop || {}
      chk = opts[ :check_install ]
      chk = check_install? if chk.nil?
      flags = Array( opts[ :yum_flags ] )
      pkgs.flatten!
      rpms,names = pkgs.partition { |p| p =~ /\.rpm$/ || p =~ /^http(s)?:/i }
      rpms.each do |url|
        dist_install_url( url, nil, opts )
      end
      !names.empty? && dist_if_not_installed?( names, chk != false, opts ) do
        sudo( "yum install -q -y #{(flags + names).join ' '}", opts )
      end
    end

    # Install packages by HTTP URL or local file path to rpm. Uses
    # name to check_install. If not specified, name is deduced via
    # `File.basename( url, '.rpm' )`. It is not recommended to set
    # option `check_install: false`, because `yum` will fail with
    # "Error: Nothing to do" if given a file/URL and the package is
    # already installed.
    #
    # ==== Options
    #
    # :check_install:: Short-circuit if package is already
    #                  installed. (Default: true)
    #
    # :yum_flags:: Additional array of flags to pass to `yum install`.
    #
    # Options are also passed to the sudo calls.
    def dist_install_url( url, name = nil, opts = {} )
      name ||= File.basename( url, '.rpm' )
      chk = opts[ :check_install ]
      flags = Array( opts[ :yum_flags ] )
      dist_if_not_installed?( name, chk != false, opts ) do
        sudo( "yum install -q -y #{(flags + [url]).join ' '}", opts )
      end
    end

    # Uninstall the specified package names. A trailing hash is
    # interpreted as options. These are passed to the sudo.
    def dist_uninstall( *pkgs )
      opts = pkgs.last.is_a?( Hash ) && pkgs.pop || {}
      pkgs.flatten!
      sudo( <<-SH, opts )
        if yum list -C -q installed #{pkgs.join ' '} >/dev/null 2>&1; then
          yum remove -q -y #{pkgs.join ' '}
        fi
      SH
    end

    # If chk is true, then wrap block in a sudo bash conditional that tests
    # if any specified pkgs are not installed. Otherwise just
    # yield to block.
    def dist_if_not_installed?( pkgs, chk, opts, &block )
      if chk
        pkgs = Array( pkgs )
        cnt = "rpm -q #{pkgs.join ' '} | grep -cv 'not installed'"
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
