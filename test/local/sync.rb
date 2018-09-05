#--
# Copyright (c) 2011-2018 David Kellum
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
    sudo_if( "[ -e /etc/init.d/iyyov ]" ) do
      dist_service( "iyyov", "stop" )
    end
    sudo <<-SH
      if [ -d /var/local/runr ]; then
        for pid in /var/local/runr/*/*.pid; do
          if [ -e "$pid" ]; then
            kill $(<$pid) || true
          fi
        done
      fi
      rm -rf /usr/local/bin/* /usr/local/lib/j* /usr/local/lib/hashdot
      rm -f /etc/init.d/iyyov
      rm -rf /var/local/runr
    SH
  end
end

class Validator < Component
  def install
    validate_running #a cheat for ease of testing
  end

  def validate_running
    sh <<-SH
     i=0
     until curl -sS http://localhost:5791 -o /dev/null; do
       sleep 1
       i=$(( $i + 1 ))
       if [ $i -gt 40 ]; then
         echo "geminabox (port 5791) not responding after 40s" >&2
         exit 91
       fi
     done
    SH
  end
end

role( :all, Users.new, EtcHosts.new )

role( :iyyov,
      Uninstaller.new,
      RunUser.new,
      OpenJDK.new,
      JRubyVM.new( jruby_version: '1.7.13' ),
      Hashdot.new,
      Iyyov.new )

role( :geminabox,
      Geminabox.new,
      Validator.new )

host( 'centos-1', RHEL.new,   Network.new, :iyyov, :geminabox, :empty_role,
      internal_ip: '192.168.122.4' )
host( 'ubuntu-1', Ubuntu.new, Network.new, :iyyov, :geminabox,
      internal_ip: '192.168.122.145' )
