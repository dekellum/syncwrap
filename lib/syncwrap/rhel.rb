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

# Customizations for RedHat Enterprise Linux and derivatives like
# CentOS and Amazon Linux.  Specific distros/versions may further
# override these.
module SyncWrap::RHEL
  include SyncWrap::Distro

  def initialize
    super

    packages_map.merge!( 'emacs' => 'emacs-nox',
                         'postgresql' => 'postgresql-server' )
  end

  # Generate command to install packages. The last argument is
  # interpreted as a options if it is a Hash.
  # === Options
  # :succeed:: Always succeed (useful for local rpms which might
  # already be installed.
  def dist_install_s( *args )
    if args.last.is_a?( Hash )
      args = args.dup
      opts = args.pop
    else
      opts = {}
    end

    args = dist_map_packages( args )

    if opts[ :succeed ]
      "yum install -q -y #{args.join ' '} || true"
    else
      "yum install -q -y #{args.join ' '}"
    end
  end

  def dist_uninstall_s( *args )
    args = dist_map_packages( args )
    "yum remove -q -y #{args.join ' '}"
  end

  def dist_install_init_service_s( name )
    "/sbin/chkconfig --add #{name}"
  end

  def dist_service_s( *args )
    "/sbin/service #{args.join ' '}"
  end

end
