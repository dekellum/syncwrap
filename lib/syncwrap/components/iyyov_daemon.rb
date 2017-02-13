#--
# Copyright (c) 2011-2017 David Kellum
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

  # Provision a gem installed, Iyyov launched and monitored jruby
  # daemon using a standard set of conventions.  Can be used directly
  # in the common case, or sub-classed as needed.
  #
  # Two :sync_paths files are searched for deployment: a config.rb and
  # a jobs.d/<name>.rb.  If concrete or .erb variants of these are not
  # found than an (empty) default/config.rb and a generic
  # default/daemon.rb.erb is used. Again, these will work in the common
  # case.
  #
  # Host component dependencies: <Distro>, JRubyVM, RunUser, Iyyov
  class IyyovDaemon < Component

    # The daemon process name, also used for service_dir (along with any
    # instance) and as the default gem_name. (required)
    attr_accessor :name

    # Name of the gem (set if different than name)
    attr_writer :gem_name

    # The (gem) version String (required)
    attr_accessor :version

    # An optional secondary instance name, useful if running more than
    # one of 'name' on a host (default: nil)
    attr_accessor :instance

    def initialize( opts = {} )
      @gem_version = nil
      @gem_name = nil
      @daemon_name = nil
      @instance = nil

      super

      raise "IyyovDaemon#name property not set" unless name
      raise "IyyovDaemon#version property not set" unless version
    end

    def gem_name
      @gem_name || @name
    end

    def install
      standard_install
    end

    protected

    def standard_install

      create_service_dir( name, instance )
      conf_changes = rput_service_config

      pid, ver = capture_running_version( name, instance )

      gem_install( gem_name, version: version ) if ver != version

      # The job_source may contain more than just this daemon
      # (i.e. additional tasks, etc.) Even if this is the
      # default/daemon.rb.erb, it might have just been changed to
      # that. So go ahead an rput in any case.
      job_changes = rput( job_source,
                          "#{iyyov_run_dir}/jobs.d/#{name_instance}.rb",
                          user: run_user )
      job_changes += iyyov_install_jobs

      # If we found a daemon pid then kill if either:
      #
      # (1) the version is the same but there was a config change or
      #     hashdot was updated (i.e. new jruby version). In this case
      #     Iyyov should be up to restart the daemon.
      #
      # (2) We are :imaging, in which case we want a graceful
      #     shutdown. In this case Iyyov should have already been kill
      #     signalled itself and will not restart the daemon.
      #
      # In all cases there is the potential that the process has
      # already stopped (i.e. crashed, etc) between above pid capture
      # and the kill.  Ignore kill failures.
      if pid &&
          ( ( ver == version && ( !conf_changes.empty? ||
                                  state[ :hashdot_updated ] ) ) ||
            state[ :imaging ] )
        rudo( "kill #{pid} || true" )
      end

      conf_changes + job_changes
    end

    def rput_service_config
      rput( config_source, "#{daemon_service_dir}/config.rb", user: run_user )
    end

    def daemon_service_dir
      service_dir( name, instance )
    end

    def name_instance
      [ name, instance ].compact.join( '-' )
    end

    def job_source
      sjob = "var/iyyov/jobs.d/#{name_instance}.rb"
      unless find_source( sjob )
        sjob = "var/iyyov/jobs.d/#{name}.rb"
        unless find_source( sjob )
          sjob = "var/iyyov/default/daemon.rb.erb"
        end
      end
      sjob
    end

    def config_source
      sconf = "var/#{name_instance}/config.rb"
      unless find_source( sconf )
        sconf = "var/#{name}/config.rb"
        unless find_source( sconf )
          sconf = 'var/iyyov/default/config.rb'
        end
      end
      sconf
    end

  end

end
