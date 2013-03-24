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

require 'syncwrap/distro'

# Customizations for Ubuntu and possibly other Debian/apt packaged
# derivatives. Specific distros/versions may further specialize.
module SyncWrap::Ubuntu
  include SyncWrap::Distro

  def initialize
    super

    packages_map.merge!( 'apr'       => 'libapr1',
                         'apr-devel' => 'libapr1-dev' )
  end

  # Generate command to install packages. The last argument is
  # interpreted as a options if it is a Hash.
  # === Options
  # :minimal:: Eqv to --no-install-recommends
  def dist_install_s( *args )
    args = args.dup
    if args.last.is_a?( Hash )
      opts = args.pop
    else
      opts = {}
    end

    args = dist_map_packages( args )
    args.unshift "--no-install-recommends" if opts[ :minimal ]
    "apt-get -yq install #{args.join ' '}"
  end

  def dist_uninstall_s( *args )
    args = dist_map_packages( args )
    "aptitude -yq purge #{args.join ' '}"
  end

  def dist_install_init_service_s( name )
    "/usr/sbin/update-rc.d #{name} defaults"
  end

  def dist_service_s( *args )
    "/usr/sbin/service #{args.join ' '}"
  end

end
