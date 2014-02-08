#--
# Copyright (c) 2011-2014 David Kellum
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

require 'syncwrap/components/ubuntu'
require 'syncwrap/components/rhel'
require 'syncwrap/components/users'
require 'syncwrap/components/run_user'
require 'syncwrap/components/open_jdk'
require 'syncwrap/components/jruby_vm'
require 'syncwrap/components/hashdot'
require 'syncwrap/components/iyyov'
require 'syncwrap/components/geminabox'

include SyncWrap

space.prepend_sync_path

class Uninstaller < Component
  def uninstall
    sudo( "if [ -e /etc/init.d/iyyov ]; then", close: "fi" ) do
      dist_service( "iyyov", "stop" )
    end
    sudo <<-SH
      if [ -d /var/local/runr ]; then
        for pid in /var/local/runr/*/*.pid; do
          if [ -e "$pid" ]; then
            kill $(<$pid)
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
      for w in 1 1 1 1 2 2 4 4 4 4 4 4 4; do
        if curl -sS http://localhost:5791 -o /dev/null; then
          exit 0
        fi
        sleep $w
      done
      exit 96
    SH
  end
end

role( :all, Users.new )

role( :iyyov,
      RunUser.new,
      OpenJDK.new,
      JRubyVM.new( jruby_version: '1.7.10' ),
      Hashdot.new,
      Iyyov.new )

role( :geminabox,
      Geminabox.new,
      Validator.new )

host( 'centos-1', RHEL.new,   Uninstaller.new, :iyyov, :geminabox, :empty_role )
host( 'ubuntu-1', Ubuntu.new, Uninstaller.new, :iyyov, :geminabox )
