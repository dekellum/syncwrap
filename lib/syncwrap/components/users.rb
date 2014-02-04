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

    # The list of user names to install. If default nil, home_users
    # will be determined by the set of home directories found in
    # local_home_root - exclude_users.
    attr_accessor :home_users

    # Local home root directory, to be resolved against src_roots.
    # (Default: home)
    attr_accessor :local_home_root

    # Set of users to exclude from synchronization (default: [])
    attr_accessor :exclude_users

    # If set, override the :ssh_user for this Component install, since
    # typically the 'normal' user (i.e your developer account) has not
    # yet been created or given sudo access.  (Default: nil)
    attr_accessor :ssh_user

    # PEM file for ssh_user.
    # (Default: nil)
    attr_accessor :ssh_user_pem

    def initialize( opts = {} )
      @home_users = nil
      @local_home_root = "home"
      @exclude_users = []
      @ssh_user = nil
      @ssh_user_pem = nil

      super
    end

    def install
      rdir = find_source( local_home_root )
      users = home_users
      users ||= rdir && Dir.entries( rdir ).select do |d|
        ( d !~ /^\./ && File.directory?( File.join( rdir, d ) ) )
      end
      users ||= []
      users -= exclude_users

      users.each do |u|
        create_user( u )
        set_sudoers( u )
      end

      users.each do |u|
        sync_home_files( u )
      end

      users.each do |u|
        fix_home_permissions( u )
      end

      #FIXME: Add special case for 'root' user?
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
      rput( "#{local_home_root}/#{user}", user: user )
    rescue SourceNotFound
      false
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
      #FIXME: make this a template?
      #FIXME: Use local_root for secure_path? (Order issue)
      #Relax, less overrides needed for Ubuntu?
      sudo <<-SH
        echo '#{user} ALL=(ALL) NOPASSWD:ALL'  > /etc/sudoers.d/#{user}
        echo 'Defaults:#{user} !requiretty'   >> /etc/sudoers.d/#{user}
        echo 'Defaults:#{user} secure_path = /sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin' \
          >> /etc/sudoers.d/#{user}
        chmod 440 /etc/sudoers.d/#{user}
      SH

      #FIXME: Centos 6.5:
      # secure_path is the same as above already
      #FIXME: echo 'Defaults:#{user} always_set_home' >> /etc/sudoers.d/#{user}
    end

    protected

    def sh( command, opts = {}, &block )
      super( command, ssh_flags.merge( opts ), &block )
    end

    def rput( *args )
      opts = args.last.is_a?( Hash ) ? ssh_flags.merge( args.pop ) : ssh_flags
      super( *args, opts )
    end

    def ssh_flags
      flags = {}
      if ssh_user
        flags[ :ssh_user ] = ssh_user
        flags[ :ssh_user_pem ] = ssh_user_pem if ssh_user_pem
      end
      flags
    end

  end

end
