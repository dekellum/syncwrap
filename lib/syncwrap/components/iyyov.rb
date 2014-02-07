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
require 'syncwrap/components/ubuntu'

module SyncWrap

  # Provision the {Iyyov}[http://rubydoc.info/gems/iyyov/] job
  # scheduler and process monitor via jruby_install_gem
  class Iyyov < Component

    attr_accessor :iyyov_version

    def initialize( opts = {} )
      @iyyov_version = '1.2.0'

      super
    end

    # Deploy iyyov gem, init.d/iyyov and at least an empty jobs.rb.
    def install
      # Shorten if the desired iyyov version is already running
      pid, ver = capture_running_version( 'iyyov' )
      unless ver == iyyov_version
        install_run_dir    #as run_user
        install_iyyov_gem  #as root
        install_iyyov_init #as root
        iyyov_restart      #as root
        true
      end
      false
    end

    # Given name and optional instance check for name.pid in
    # service_dir and extracts the version number from the associated
    # cmdline. If this is running out of installed gem directory
    # (Iyyov itself, standard Iyyov daemons) then cmdline should
    # reference the gem version.
    # Returns [pid, version] or nil if not found running
    def capture_running_version( name, instance = nil )
      sdir = service_dir( name, instance )
      code, out = capture( <<-SH, user: run_user, accept:[0,1,91] )
        pid=$(< #{sdir}/#{name}.pid)
        if [[ $(< /proc/$pid/cmdline) =~ -(([0-9]+)(\\.[0-9A-Za-z]+)+)[-/] ]]; then
          echo $pid ${BASH_REMATCH[1]}
          exit 0
        fi
        exit 91
      SH
      # Above accepts exit 1 as from $(< missing-file), since it would
      # be a race to pre-check. Note '\\' escape is for this
      # ruby here-doc.

      if code == 0
        pid, ver = out.strip.split( ' ' )
        [ pid.to_i, ver ]
      else
        nil
      end
    end

    # Install a specific iyyov/jobs.d/<JOB>.rb file that works with
    # the default (this sync root) jobs.rb. This also calls
    # iyyov_install_jobs for the jobs.rb root file.
    def iyyov_install_job( comp, job_file, force = false )

      changes = comp.rput( "var/iyyov/jobs.d/#{job_file}",
                           "#{iyyov_run_dir}/jobs.d/",
                           user: run_user )
      changes + iyyov_install_jobs( force && changes.empty? )
    end

    # Update remote (run_dir/) iyyov/jobs.rb. If force is true, touch
    # root jobs.rb even if it was not changed: forcing an iyyov config
    # reload.  Returns any changes in the rput change format,
    # including any forced mtime update.
    def iyyov_install_jobs( force = false )

      changes = rput( 'var/iyyov/jobs.rb', iyyov_run_dir, user: run_user )

      if force && changes.empty?
        rudo "touch #{iyyov_run_dir}/jobs.rb"
        changes << [ '.f..T......', "#{iyyov_run_dir}/jobs.rb" ]
      end
      changes
    end

    def iyyov_run_dir
      "#{run_dir}/iyyov"
    end

    # Create iyyov run directory and make sure there is at minimum an
    # empty jobs file. Avoid touching it if already present
    def install_run_dir
      rudo <<-SH
        mkdir -p #{iyyov_run_dir}
        mkdir -p #{iyyov_run_dir}/jobs.d

        if [ ! -e #{iyyov_run_dir}/jobs.rb ]; then
          touch #{iyyov_run_dir}/jobs.rb
        fi
      SH
    end

    # Ensure install of same gem version as init.d/iyyov script
    def install_iyyov_gem
      jruby_install_gem( 'iyyov', version: "=#{iyyov_version}", minimize: true )
    end

    # Install iyyov daemon init.d script and add to init daemons
    def install_iyyov_init
      rput( 'etc/init.d/iyyov', user: :root,
            erb_vars: { lsb: distro.kind_of?( Ubuntu ) } )

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
