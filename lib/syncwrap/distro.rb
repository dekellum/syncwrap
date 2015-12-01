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

require 'syncwrap/base'

module SyncWrap

  # Support module and interface for distribution components.
  module Distro

    # The root directory for local, non-distro managed installs
    # (default: /usr/local)
    attr_accessor :local_root

    def initialize( *args )
      @local_root = '/usr/local'

      super( *args )
    end

    # Return self, and in Context, the specific Distro component.
    def distro
      self
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
    # :minimal:: Avoid additional "optional" packages when possible
    #
    # Additional options are passed to the sudo calls.
    def dist_install( *pkgs )
      raise "Include a distro-specific component, e.g. Debian, RHEL"
    end

    # Uninstall the specified package names. A trailing hash is
    # interpreted as options, passed to the sudo calls.
    def dist_uninstall( *pkgs )
      raise "Include a distro-specific component, e.g. Debian, RHEL"
    end

    # Install a System V style init.d script (already placed at remote
    # /etc/init.d/<name>) via distro-specific command. Note that this
    # should not be called and may fail on a distro running systemd. A
    # rough equivalent in this case is:
    #
    #   systemctl( 'enable', 'name.service' )
    #
    # See #systemd?, SystemD#systemctl
    #
    def dist_install_init_service( name )
      raise "Include a distro-specific component, e.g. Debian, RHEL"
    end

    # Run via sudo as root, either a System V (distro specific)
    # `service` command or the systemd `systemctl` equivalent.  In the
    # System V case arguments are passed verbatim and are in the form:
    # (name, command, options...) Typically supported commands
    # include: start, stop, restart, reload and status.  For maximum
    # compatibility, in the systemd case only two arguments are
    # allowed: shortname, command. Note the order is reversed from the
    # use of systemctl.
    def dist_service( *args )
      raise "Include a distro-specific component, e.g. Debian, RHEL"
    end

    # If found mounted, unmount the specified device and also remove
    # it from fstab.
    def unmount_device( dev )
      sudo <<-SH
        if mount | grep -q '^#{dev} '; then
          umount #{dev}
          sed -r -i '\\|^#{dev}\\s|d' /etc/fstab
        fi
      SH
    end

    # Is the Distro running systemd?
    def systemd?
      false
    end

  end

end
