#--
# Copyright (c) 2011-2012 David Kellum
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
require 'syncwrap/distro'

module SyncWrap::Ubuntu
  include SyncWrap::Distro

  def initialize
    super

    packages_map.merge!( 'apr'       => 'libapr1',
                         'apr-devel' => 'libapr1-dev' )
  end

  def dist_install( *pkgs )
    pkgs = dist_map_packages( pkgs )
    sudo "apt-get -yq install #{pkgs.join( ' ' )}"
  end

  def dist_uninstall( *pkgs )
    pkgs = dist_map_packages( pkgs )
    sudo "aptitude -yq purge #{pkgs.join( ' ' )}"
  end

  def dist_install_init_service( name )
    sudo "/usr/sbin/update-rc.d #{name} defaults"
  end

  def dist_service( *args )
    sudo( [ '/usr/sbin/service' ] + args )
  end

end
