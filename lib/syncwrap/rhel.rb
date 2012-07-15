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

  # FIXME
  # rpm -Uvh \
  # http://linux.mirrors.es.net/fedora-epel/6/x86_64/ \
  # epel-release-6-7.noarch.rpm

  def dist_install( *pkgs )
    pkgs = dist_map_packages( pkgs )
    sudo "yum install -qy #{pkgs.join( ' ' )}"
  end

  def dist_uninstall( *pkgs )
    pkgs = dist_map_packages( pkgs )
    sudo "yum remove -qy #{pkgs.join( ' ' )}"
  end

  def dist_install_init_service( name )
    sudo "/sbin/chkconfig --add #{name}"
  end

  def dist_service( *args )
    sudo( [ '/sbin/service' ] + args )
  end

end
