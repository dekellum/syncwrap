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

require 'syncwrap/base'

module SyncWrap

  # Support module and inteface for (Linux) distribution components.
  module Distro

    # The root directory for local, non-distro managed installs
    # (default: /usr/local)
    attr_accessor :local_root

    # A Hash of internal/common package names to distro specific package
    # names.
    attr_reader :packages_map

    def initialize( *args )
      @local_root = '/usr/local'
      @packages_map = {}

      super( *args )
    end

    # Return self, and in Context, the specific Distro component.
    def distro
      self
    end

    # Map internal/common names and return distro-specific names. If a
    # mapping does not exist, return the original name.
    def dist_map_packages( *pkgs )
      pkgs.flatten.compact.map { |pkg| packages_map[ pkg ] || pkg }
    end

    # Install the specified packages using distro-specific mapped
    # package names. A trailing hash is interpreted as options, see
    # below.
    #
    # ==== Options
    #
    # :succeed:: Always succeed (useful for local rpms which might
    #            already be installed.
    #
    # :minimal:: Avoid additional "optional" packages when possible.
    def dist_install( *pkgs )
      raise "Include a distro-specific component, e.g. Ubuntu, RHEL"
    end

    # Uninstall specified packages using distro-specific mapped
    # package names and command.
    def dist_uninstall( *pkgs )
      raise "Include a distro-specific component, e.g. Ubuntu, RHEL"
    end

    # Install a System V style init.d script (already placed at remote
    # /etc/init.d/<name>) via distro-specific command
    def dist_install_init_service( name )
      raise "Include a distro-specific component, e.g. Ubuntu, RHEL"
    end

    # Run via sudo, the System V style, distro specific `service`
    # command, typically supporting 'start', 'stop', 'restart',
    # 'status', etc. arguments.
    def dist_service( *args )
      raise "Include a distro-specific component, e.g. Ubuntu, RHEL"
    end

  end

end
