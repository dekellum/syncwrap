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

# For distro class comparison only (pre-load for safety)
require 'syncwrap/components/debian'

module SyncWrap

  # Provision the {Iyyov}[http://rubydoc.info/gems/iyyov/] job
  # scheduler and process monitor via jruby_gem_install. The
  # installation setup and configuration templates assume use of a
  # jobs.d directory, as supported in \Iyyov 1.3.0.
  #
  # Host component dependencies: <Distro>, JRubyVM, RunUser
  class Iyyov < Component

    attr_accessor :iyyov_version

    def initialize( opts = {} )
      @iyyov_version = '1.3.0'

      super
    end

    # Deploy iyyov gem, init.d script or systemd unit, and at least an
    # empty jobs.rb.
    def install
      # Shorten if the desired iyyov version is already running
      _,ver = capture_running_version( 'iyyov' )
      if ver != iyyov_version
        install_run_dir    #as root
        install_iyyov_gem  #as root
        install_iyyov_init #as root
        iyyov_restart unless state[ :imaging ] #as root
        true
      elsif state[ :hashdot_updated ] && !state[ :imaging ]
        iyyov_restart
        true
      end

      # FIXME: There is a potential race condition brewing here. If
      # Iyyov is restarted, then job changes (i.e. jobs.d files) are
      # immediately made before Iyyov is done reloading, then those
      # changes may not be detected. Thus job upgrades may not occur.
      # This might be best fixed in Iyyov itself.

      iyyov_stop if state[ :imaging ]
      false
    end

    # Given name(-instance), check for name.pid in service_dir and
    # extract the version number from the associated cmdline. If this
    # is running out of installed gem directory (Iyyov itself,
    # standard Iyyov daemons) then cmdline should reference the gem
    # version.  Returns [pid, version] or nil if not found running
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

    # Update remote (run_dir/) iyyov/jobs.rb. If force is true, touch
    # root jobs.rb even if it was not changed: forcing an iyyov config
    # reload.  Returns any changes in the rput change format,
    # including any forced mtime update.
    def iyyov_install_jobs( force = false )

      changes = []

      if force || !state[ :iyyov_root_jobs_installed ]
        changes += rput( 'var/iyyov/jobs.rb', iyyov_run_dir, user: run_user )
        state[ :iyyov_root_jobs_installed ] = true
      end

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
    # empty jobs file. Avoid touching it if already present.
    def install_run_dir
      # Run as root for merging with the other install fragments.
      sudo <<-SH
        mkdir -p #{iyyov_run_dir}
        mkdir -p #{iyyov_run_dir}/jobs.d
      SH
      chown_run_user( '-R', iyyov_run_dir )
      sudo <<-SH
        if [ ! -e #{iyyov_run_dir}/jobs.rb ]; then
          su #{run_user} -c "touch #{iyyov_run_dir}/jobs.rb"
        fi
      SH
    end

    # Ensure install of same gem version as init.d script or unit file
    def install_iyyov_gem
      jruby_gem_install( 'iyyov', version: iyyov_version )
    end

    # Install iyyov daemon init.d script or service unit
    def install_iyyov_init
      if systemd?
        changes = rput( 'etc/systemd/system/iyyov.service', user: :root )
        systemctl( 'daemon-reload' ) unless changes.empty?
        systemctl( 'enable', 'iyyov.service' )
      else
        rput( 'etc/init.d/iyyov', user: :root,
              erb_vars: { lsb: distro.kind_of?( Debian ) } )

        # Add to init.d
        dist_install_init_service( 'iyyov' )
      end
    end

    def start
      dist_service( 'iyyov', 'start' )
    end

    def stop
      dist_service( 'iyyov', 'stop' )
    end

    def restart
      dist_service( 'iyyov', 'restart' )
    end

    # Output the server status (useful via CLI with --verbose)
    def status
      dist_service( 'iyyov', 'status' )
    end

    # Reload server configuration
    def reload
      dist_service( 'iyyov', 'reload' )
    end

    protected

    alias :iyyov_start   :start
    alias :iyyov_restart :restart
    alias :iyyov_stop    :stop

  end

end
