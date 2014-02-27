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
require 'syncwrap/path_util'

module SyncWrap

  # Provision developer user accounts, sudo access, and synchronize
  # home directory files.
  class Users < Component
    include PathUtil

    # The list of user names to install. If default nil, home_users
    # will be determined by the set of home directories found in
    # local_home_root - exclude_users.
    attr_accessor :home_users

    # Local home root directory, to be resolved against sync_paths.
    # (Default: home)
    attr_accessor :local_home_root

    # Set of users to exclude from synchronization (default: [])
    attr_accessor :exclude_users

    # If set, override the :ssh_user for this Component install, since
    # typically the 'normal' user (i.e your developer account) has not
    # yet been created or given sudo access.  (Default: nil)
    attr_accessor :ssh_user

    # A PEM file for the ssh_user. A relative path in interpreted as
    # relative to the sync file from which this component is
    # created. If the pem file is not found, a warning will be issued
    # and ssh_user and ssh_user_pem will not be used.
    # (Default: nil)
    attr_accessor :ssh_user_pem

    # Users should be the first component to attempt ssh access. On
    # new host creation, install may be run before the ssh port is
    # actually available (boot completed, etc.). This provides an
    # additional timeout in seconds for establishing the first ssh
    # session. (default: 180 seconds)
    attr_accessor :ssh_access_timeout

    # Use the StrictHostKeyChecking=no ssh option when connected to a
    # newly created host (whose key will surely not be known yet.)
    # (Default: true)
    attr_accessor :lenient_host_key

    def initialize( opts = {} )
      @home_users = nil
      @local_home_root = "home"
      @exclude_users = []
      @ssh_user = nil
      @ssh_user_pem = nil
      @ssh_access_timeout = 180.0
      @lenient_host_key = true
      super

      if @ssh_user_pem
        @ssh_user_pem =
          relativize( path_relative_to_caller( @ssh_user_pem, caller ) )
        unless File.exist?( @ssh_user_pem )
          warn( "WARNING: Users pem #{@ssh_user_pem} not found. " +
                "Will not use #{@ssh_user}.\n" +
                "Components may fail without sudo access" )
          @ssh_user = nil
          @ssh_user_pem = nil
        end
      end
    end

    def install
      ensure_ssh_access if state[ :just_created ] && ssh_access_timeout > 0

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

    def ensure_ssh_access
      flags = ssh_flags
      if lenient_host_key
        flags[ :ssh_options ] ||= {}
        flags[ :ssh_options ][ 'StrictHostKeyChecking' ] = 'no'
      end

      start = Time.now
      loop do
        accept  = [0]
        # Allow non-sucess until timeout
        # 255: ssh (i.e. can't connect, sshd not yet up)
        # 1: sudo error (user_data sudoers update has not yet completed)
        accept += [1, 255] unless ( Time.now - start ) >= ssh_access_timeout

        code,_ = capture( 'sudo true', flags.merge( accept: accept ) )
        break if code == 0
        sleep 1 # ssh timeouts also apply, but make sure we don't spin
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
        if ssh_user_pem
          flags[ :ssh_user_pem ] = ssh_user_pem
          flags[ :ssh_options ] = { 'IdentitiesOnly' => 'yes' }
        end
      end
      flags
    end

  end

end
