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

  # Provision the {Iyyov}[http://rubydoc.info/gems/iyyov/] job
  # scheduler and process monitor via jruby_install_gem
  class Iyyov < Component

    attr_accessor :iyyov_version

    def initialize( opts = {} )
      @iyyov_version = '1.2.0'

      super
    end

    # Deploy iyyov gem, init.d/iyyov and at least an empty
    # jobs.rb. Returns true if iyyov was installed/upgraded and should
    # be restarted.
    def install
      # Short-circuit install if the right process is already running
      dtest = "iyyov-#{iyyov_version}-java/init/iyyov"
      code,_ = capture( "pgrep -f #{dtest}", accept:[0,1] )

      if code == 1
        install_run_dir
        install_iyyov_gem
        install_iyyov_init
        iyyov_restart
        true
      end
    end

    # Update remote (run_user) var/iyyov/jobs.rb; which will trigger
    # any necessary restarts.  For backward compatibility, yields to
    # block if given for daemon install, etc. However, this can more
    # simply be done beforehand.
    def iyyov_install_jobs

      # Any Iyyov restart completes *before* job changes
      yield if block_given?

      changes = rput( 'var/iyyov/jobs.rb', iyyov_run_dir, user: run_user )

      rudo "touch #{iyyov_run_dir}/jobs.rb" if changes.empty?
    end

    def iyyov_run_dir
      "#{run_dir}/iyyov"
    end

    # Create iyyov run directory and make sure there is at minimum an
    # empty jobs file. Avoid touching it if already present
    def install_run_dir
      rudo <<-SH
        mkdir -p #{iyyov_run_dir}
        if [ ! -e #{iyyov_run_dir}/jobs.rb ]; then
          touch #{iyyov_run_dir}/jobs.rb
        fi
      SH
      chown_run_user( '-R', iyyov_run_dir )
    end

    # Ensure install of same gem version as init.d/iyyov script
    # Return true if installed
    def install_iyyov_gem
      gem_count = jruby_install_gem( 'iyyov', version: "=#{iyyov_version}",
                                     minimize: true, check: true )
      ( gem_count > 0 )
      # FIXME may not need to check
    end

    # Install iyyov daemon init.d script and add to init daemons
    def install_iyyov_init
      # FIXME: Templatize for version or pull out of gem sample
      rput( 'etc/init.d/iyyov', user: :root )

      # Add to init.d
      dist_install_init_service( 'iyyov' )
    end

    def iyyov_start
      dist_service( 'iyyov', 'start' )
    end

    def iyyov_stop
      dist_service( 'iyyov', 'stop' )
    end

    def iyyov_restart
      dist_service( 'iyyov', 'restart' )
    end

  end

end
