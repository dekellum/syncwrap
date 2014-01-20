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

  # Provision a user to run daemons within a run directory. Utilities
  # for working with the same.
  class RunUser < Component

    # A user for running deployed daemons, jobs (default: 'runr')
    attr_accessor :run_user

    # A group for running (default: nil -> same as run_user)
    attr_accessor :run_group

    # Root directory for persistent data and logs
    # (default: /var/local/#{run_user})
    attr_writer :run_dir

    def run_dir
      @run_dir || "/var/local/#{run_user}"
    end

    def initialize( opts = {} )
      @run_user    = 'runr'
      @run_group   = nil
      @run_dir     = nil

      super
    end

    def install
      create_run_user
      create_run_dir
    end

    # Create run_user if not already present
    def create_run_user
      sudo( "if ! id #{run_user} >/dev/null 2>&1; then", close: "fi" ) do
        if run_group && run_group != run_user
          sudo <<-SH
            groupadd -f #{run_group}
            useradd -g #{run_group} #{run_user}
          SH
        else
          sudo "useradd #{run_user}"
        end
      end
    end

    # Create and set owner/permission of run_dir, such that run_user may
    # create new directories there.
    def create_run_dir
      make_dir( run_dir )
    end

    def service_dir( sname, instance = nil )
      run_dir + '/' + [ sname, instance ].compact.join( '-' )
    end

    # Create and set owner/permission of a named service directory under
    # run_dir.
    def create_service_dir( sname, instance = nil )
      sdir = service_dir( sname, instance )
      make_dir( sdir )
    end

    def make_dir( dir )
      sudo "mkdir -p #{dir}"
      chown_run_user dir
      sudo "chmod 775 #{dir}"
    end

    # Chown to user:run_group where args may be flags and files/directories.
    def chown_run_user( *args )
      flags, paths = args.partition { |a| a =~ /^-/ }
      sudo( [ 'chown', flags,
              [ run_user, run_group || run_user ].join(':'),
              paths ].flatten.compact.join( ' ' ) )
    end

  end

end
