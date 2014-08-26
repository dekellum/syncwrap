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

  # Provision a source/bundle installed, Iyyov launched and monitored jruby
  # daemon using a standard set of conventions.  Can be used directly
  # in the common case, or sub-classed as needed.
  #
  # Two :sync_paths files are searched for deployment: a config.rb and
  # a jobs.d/<name>.rb.  If concrete or .erb variants of these are not
  # found than an (empty) default/config.rb and a generic
  # default/bundled_daemon.rb.erb is used. Again, these will work in
  # the common case.
  #
  # Host component dependencies: RunUser, <ruby>, Iyyov
  class BundledIyyovDaemon < Component

    protected

    # The daemon process name. (Default: SourceTree#source_dir)
    attr_writer :name

    def name
      @name || source_dir
    end

    # An optional secondary instance name, useful if running more than
    # one of 'name' on a host. (Default: nil)
    attr_accessor :instance

    # An optional state key to check, indicating changes requiring
    # a daemon restart (Default: nil; Example: :source_tree)
    attr_accessor :change_key

    public

    def initialize( opts = {} )
      @name = nil
      @instance = nil
      @change_key = nil

      super
    end

    def install
      standard_install
    end

    protected

    def standard_install
      conf_changes = rput_service_config

      # The job_source may contain more than just this daemon
      # (i.e. additional tasks, etc.) Even if this is the
      # default/daemon.rb.erb, it might have just been changed to
      # that. So go ahead an rput in any case.
      job_changes = rput( job_source,
                          "#{iyyov_run_dir}/jobs.d/#{name_instance}.rb",
                          user: run_user )
      job_changes += iyyov_install_jobs

      src_changes = ( change_key && state[ change_key ] ) || []

      if ( ( src_changes + conf_changes ).length > 0 ||
           state[ :hashdot_updated ] ||
           state[ :imaging ] )
        rudo( "kill $(< #{daemon_service_dir}/#{name}.pid ) || true" )
      end

      conf_changes + job_changes
    end

    def rput_service_config
      rput( config_source, "#{daemon_service_dir}/config.rb", user: run_user )
    end

    def daemon_service_dir
      service_dir( name, instance )
    end

    def exe_path
      File.join( daemon_service_dir, 'init', name )
    end

    def name_instance
      [ name, instance ].compact.join( '-' )
    end

    def job_source
      sjob = "var/iyyov/jobs.d/#{name_instance}.rb"
      unless find_source( sjob )
        sjob = "var/iyyov/jobs.d/#{name}.rb"
        unless find_source( sjob )
          sjob = "var/iyyov/default/bundled_daemon.rb.erb"
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
