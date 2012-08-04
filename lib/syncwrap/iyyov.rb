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

require 'syncwrap/user_run'
require 'syncwrap/distro'
require 'syncwrap/jruby'

# Provisions the {Iyyov}[http://rubydoc.info/gems/iyyov/] job
# scheduler and process monitor by jruby_install_gem.
module SyncWrap::Iyyov
  include SyncWrap::UserRun
  include SyncWrap::Distro
  include SyncWrap::JRuby

  attr_accessor :iyyov_version

  def initialize
    super

    @iyyov_version = '1.1.3'
  end

  # Install then (re-)start Iyyov if needed, yield to block if given
  # for daemon gem or other setup, then finally update remote
  # (user_run) var/iyyov/jobs.rb; which will trigger any necessary
  # restarts.
  def iyyov_install_jobs
    user_run_dir_setup

    restart = iyyov_install
    if restart
      iyyov_restart
      sleep 15
    elsif !exist?( "#{iyyov_run_dir}/iyyov.pid" )
      iyyov_start
      sleep 15
    end

    # FIXME: Need a better solution to wait on Iyyov than an arbitrary
    # sleep.

    # Any Iyyov restart completes *before* job changes

    yield if block_given?

    user_run_rput( 'var/iyyov/jobs.rb', iyyov_run_dir )

    # FIXME: If no jobs.rb change, still touch file to ensure
    # check, but avoid both an update and a touch...

  end

  # Deploy iyyov gem, init.d/iyyov and at least an empty
  # jobs.rb. Returns true if iyyov was installed/upgraded and should
  # be restarted.
  def iyyov_install
    iyyov_install_rundir

    if iyyov_install_gem
      iyyov_install_init!
      true
    else
      false
    end

  end

  def iyyov_run_dir
    "#{user_run_dir}/iyyov"
  end

  # Create iyyov rundir and make sure there is at minimum an empty
  # jobs file. Avoid touching it if already present
  def iyyov_install_rundir
    sudo( <<-"SH", :user => user_run )
      mkdir -p #{iyyov_run_dir}
      if [ ! -e #{iyyov_run_dir}/jobs.rb ]; then
        touch #{iyyov_run_dir}/jobs.rb
      fi
    SH
    user_run_chown( '-R', iyyov_run_dir )
  end

  # Ensure install of same gem version as init.d/iyyov script
  # Return true if installed
  def iyyov_install_gem
    jruby_install_gem( 'iyyov', :version => "=#{iyyov_version}",
                       :check => true )
  end

  # Install iyyov daemon init.d script and add to init daemons
  def iyyov_install_init!
    rput( 'etc/init.d/iyyov', :user => 'root' )

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
