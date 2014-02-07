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

  # Provision the
  # {boxed-geminabox}[https://github.com/dekellum/boxed-geminabox/]
  # gem server.
  # FIXME: Break out a reusable IyyovDaemon component with generic
  # job.rb template.
  # Component dependencies: jruby, iyyov, run_user
  class Geminabox < Component

    attr_accessor :geminabox_version

    def initialize( opts = {} )
      @geminabox_version = '1.1.0'

      super
    end

    def daemon_service_dir
      service_dir( 'boxed-geminabox' )
    end

    def install
      create_service_dir( 'boxed-geminabox' )

      src = 'var/boxed-geminabox/config.rb'
      unless find_source( src )
        src = 'var/iyyov/empty_config.rb'
      end
      changes = rput( src, "#{daemon_service_dir}/config.rb", user: run_user )

      # Shorten if the desired versioned process is already running.
      pid, ver = capture_running_version( "boxed-geminabox" )
      if ver != geminabox_version
        jruby_install_gem( 'boxed-geminabox',
                           version: "=#{geminabox_version}",
                           minimize: true )
        changes += iyyov_install_job( self, 'boxed-geminabox.rb' )
      elsif !changes.empty?
        rudo( "kill #{pid} || true" ) # ..and let Iyyov restart it
      end
      changes
   end

  end

end
