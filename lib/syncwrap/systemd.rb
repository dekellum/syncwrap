#--
# Copyright (c) 2011-2015 David Kellum
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

module SyncWrap

  # Support module for the systemd service manager, PID 1
  module SystemD

    # Run systemd `systemctl` command with args via sudo as root.
    def systemctl( *args )
      sudo "/usr/bin/systemctl #{args.join ' '}"
    end

    # Expand given shortname to "shortname.service" as used for the
    # systemd unit.
    def dot_service( shortname )
      shortname + ".service"
    end

    protected

    # Provides Distro#dist_service compatibility via #systemctl. The
    # argument order is swapped and shortname is passed through
    # #dot_service.
    def dist_service_via_systemctl( shortname, action )
      systemctl( action, dot_service( shortname ) )
    end

  end
end
