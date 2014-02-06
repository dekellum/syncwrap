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

    def install
      create_service_dir( 'boxed-geminabox' )

      if find_source( 'var/boxed-geminabox/config.rb' )
        changes = rput( 'var/boxed-geminabox/config.rb',
                        service_dir( 'boxed-geminabox' ),
                        user: run_user )
        config_changed = !changes.empty?
      else
        conf = "#{service_dir( 'boxed-geminabox' )}/config.rb"
        code,_ = capture( <<-SH, user: run_user, accept: [0,91] )
          if [ -f "#{conf}" ]; then
            mv -f #{conf} #{conf}~
            exit 91
          fi
        SH
        config_changed = (code == 91)
      end

      # Short-circuit if the correct versioned process is already
      # running. The pattern starts with jruby to avoid undesired
      # match on the wrapping ssh command, The '.*' includes '-java',
      # or not
      dpat = "^jruby .*boxed-geminabox-#{geminabox_version}.*/init/boxed-geminabox"
      code, pid = capture( "pgrep -f '#{dpat}'", accept:[0,1] )

      if code == 1
        jruby_install_gem( 'boxed-geminabox',
                           version: "=#{geminabox_version}",
                           minimize: true )
        iyyov_install_job( self, 'boxed-geminabox.rb' )
      elsif config_changed
        rudo( "kill #{pid.strip} || true" ) # ..and let Iyyov restart it
      end

    end

  end

end
