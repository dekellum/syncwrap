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

require 'syncwrap/component'

module SyncWrap

  # Provision developer user accounts, sudo access, and synchronize
  # home directory files.
  class Users < Component

    # The list of user names to install. If nil, home_users will be
    # determined by the set of home directories in local_home_dir -
    # exclude_users.
    attr_accessor :home_users

    # Local set of home directories to be synchronized. (Default: ./home)
    attr_accessor :local_home_dir

    # Set of users to exclude from synchronization (default: [])
    attr_accessor :exclude_users

    def initialize( opts = {} )
      @home_users = nil
      @local_home_dir = "./home"
      @exclude_users = []
      super
    end

    def install
      users = home_users
      users ||= Dir.entries( local_home_dir ).select do |d|
        ( d !~ /^\./ &&
          File.directory?( local_home_dir + d ) )
      end
      users -= exclude_users

      users.each do |u|
        sync_home_files( u )
      end

      users.each do |u|
        create_user( u )
        fix_home_permissions( u )
        set_sudoers( u )
      end
    end

    # Create user if not already present
    def create_user( user )
      sudo <<-SH
        if ! id #{user} >/dev/null 2>&1; then
          useradd #{user}
        fi
      SH
    end

    def sync_home_files( user )
      if File.directory?( "#{local_home_dir}/#{user}" )
        rput( "#{local_home_dir}/#{user}", user: user )
      else
        false
      end
    end

    def fix_home_permissions( user )
      sudo <<-SH
        if [ -e '/home/#{user}/.ssh' ]; then
          chmod 700 /home/#{user}/.ssh
          chmod -R o-rwx /home/#{user}/.ssh
        fi
      SH
    end

    def set_sudoers( user )
      #FIXME: make this a template, Use commons bin for secure_path
      #Relax, less overrides needed for Ubuntu?
      sudo <<-SH
        echo '#{user} ALL=(ALL) NOPASSWD:ALL'  > /etc/sudoers.d/#{user}
        echo 'Defaults:#{user} !requiretty'   >> /etc/sudoers.d/#{user}
        echo 'Defaults:#{user} secure_path = /sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin' \
          >> /etc/sudoers.d/#{user}
        chmod 440 /etc/sudoers.d/#{user}
      SH
    end

  end

end
