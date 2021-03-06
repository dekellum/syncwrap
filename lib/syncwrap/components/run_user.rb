#--
# Copyright (c) 2011-2018 David Kellum
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

  # Provision a user to run daemons within a run directory. Utilities
  # for working with the same.
  class RunUser < Component

    # A user for running deployed daemons, jobs (default: 'runr')
    attr_accessor :run_user

    # A group for running (default: nil -> same as #run_user)
    attr_accessor :run_group

    # Root directory for persistent data and logs
    # (default: /var/local/#{run_user})
    attr_writer :run_dir

    def run_dir
      @run_dir || "/var/local/#{run_user}"
    end

    # File mode as integer for the #run_dir (default: 0755)
    attr_accessor :run_dir_mode

    # Home directory for the #run_user
    # (default: nil -> same as #run_dir)
    attr_writer :run_user_home

    def run_user_home
      @run_user_home || run_dir
    end

    def initialize( opts = {} )
      @run_user    = 'runr'
      @run_group   = nil
      @run_dir     = nil
      @run_dir_mode = 0755
      @run_user_home = nil
      super
    end

    def install
      create_run_user
      create_run_dir
    end

    # Create run_user if not already present
    def create_run_user
      sudo_if( "! id #{run_user} >/dev/null 2>&1" ) do
        user_opts  = "-r -c 'Run User' -s /bin/bash"
        user_opts += " -d #{run_user_home}" if run_user_home
        if run_group && run_group != run_user
          sudo "groupadd -r -f #{run_group}"
          user_opts += " -g #{run_group}"
        end
        sudo "useradd #{user_opts} #{run_user}"
      end
    end

    # Create and set owner/permission of run_dir, such that run_user may
    # create new directories there.
    def create_run_dir
      mkdir_run_user( run_dir, mode: run_dir_mode )
    end

    def service_dir( sname, instance = nil )
      run_dir + '/' + [ sname, instance ].compact.join( '-' )
    end

    # Create and set owner/permission of a named service directory under
    # run_dir.
    def create_service_dir( sname, instance = nil )
      sdir = service_dir( sname, instance )
      mkdir_run_user( sdir )
    end

    # Make dir including parents via sudo, chown to run_user, and chmod
    # === Options
    # :mode:: Integer file mode for directory set via chmod (Default: 0775)
    def mkdir_run_user( dir, opts = {} )
      mode = opts[:mode] || 0775
      sudo "mkdir -p #{dir}"
      chown_run_user dir
      sudo( "chmod %o %s" % [ mode, dir ] )
    end

    # Deprecated
    alias make_dir mkdir_run_user

    # Chown to user:run_group where args may be flags and files/directories.
    def chown_run_user( *args )
      flags, paths = args.partition { |a| a =~ /^-/ }
      sudo( [ 'chown', flags,
              [ run_user, run_group || run_user ].join(':'),
              paths ].flatten.compact.join( ' ' ) )
    end

  end

end
