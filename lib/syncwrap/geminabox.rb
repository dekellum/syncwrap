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
  # Component dependencies: jruby, iyyov, run_user
  class Geminabox < Component

    attr_accessor :geminabox_version

    def initialize( opts = {} )
      @geminabox_version = '1.0.0'

      super
    end

    def install
      # Short-circuit if the correct versioned process is already running
      dpat = "boxed-geminabox-#{geminabox_version}-java/init/boxed-geminabox"
      code,_ = capture( "pgrep -f #{dpat}", accept:[0,1] )

      if code == 1
        jruby_install_gem( 'boxed-geminabox', version: "=#{geminabox_version}" )
        create_service_dir( 'boxed-geminabox' )
        iyyov_install_jobs
      end
    end

  end

end
