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

require 'syncwrap/base'

# Support for distro specializations.
module SyncWrap::Distro

  # A Hash of internal/common package names to distro specific package
  # names.  Here defined as empty.
  attr_reader :packages_map

  def initialize
    super

    @packages_map = {}
  end

  # Map internal/common names and return distro-specific names. If a
  # mapping does not exist, assume internal name is a common name and
  # return.
  def dist_map_packages( *pkgs )
    pkgs.flatten.compact.map { |pkg| packages_map[ pkg ] || pkg }
  end

  # Install the specified packages using distro-specific mapped
  # package names and command.
  def dist_install( *pkgs )
    raise "Include a distro-specific module, e.g. Ubuntu, RHEL"
  end

  # Uninstall specified packages using distro-specific mapped
  # package names and command.
  def dist_uninstall( *pkgs )
    raise "Include a distro-specific module, e.g. Ubuntu, RHEL"
  end

  # Install a System V style init.d script (already placed at remote
  # /etc/init.d/<name>) via distro-specific command
  def dist_install_init_service( name )
    raise "Include a distro-specific module, e.g. Ubuntu, RHEL"
  end

  # Distro (and System V replacement) specific service command,
  # typically supporting 'start', 'stop', 'restart', 'status',
  # etc. argumnets.
  def dist_service( *args )
    raise "Include a distro-specific module, e.g. Ubuntu, RHEL"
  end

end
