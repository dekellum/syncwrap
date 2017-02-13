#--
# Copyright (c) 2011-2017 David Kellum
#
# Licensed under the Apache License, Version 2.0 (the "License"); you
# may not use this file except in compliance with the License.  You
# may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.  See the License for the specific language governing
# permissions and limitations under the License.
#++

# This sync.rb example provides some integration testing. It depends
# on local VMs ssh accessible at "ubuntu-1" and "centos-1". Note this
# can make potentially damaging changes to these hosts!

include SyncWrap

space.prepend_sync_path # local's

class Uninstaller < Component
  def uninstall
    sudo( "if [ -e /usr/local/sbin/qpidd -a -e /etc/init.d/qpidd ]; then",
          close: "fi" ) do
      dist_service( "qpidd", "stop" )
    end
    sudo <<-SH
      rm -rf /tmp/src /usr/local/sbin/qpidd
      yum -y -q erase corosync corosynclib-devel corosynclib
    SH
  end
end

role( :all, Users.new, EtcHosts.new )

host( 'centos-1', RHEL.new, Network.new, Uninstaller.new, Qpid.new,
      internal_ip: '192.168.122.4' )
