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

module SyncWrap

  # Support module for the systemd service manager, PID 1
  module SystemD

    # Run systemd `systemctl` command with args via sudo. If the first
    # arg is 'status', defer to #systemctl_status.  A trailing hash is
    # interpreted as options and passed to sudo. Since systemctl
    # returns non-zero for a variety of normal conditions, the :accept
    # option can be passed to account for these, as well as :error =>
    # false.
    def systemctl( *args )
      opts = args.last.is_a?( Hash ) && args.pop || {}
      args.flatten!
      if args.first == 'status'
        args.shift
        systemctl_status( *args, opts )
      else
        sudo( "systemctl #{args.join ' '}", opts )
      end
    end

    # Run `systemctl status` via sudo, with special case stripping of
    # whitespace from the end of line output via a sed filter. This is
    # not an issue with an interactive terminal because output is
    # piped to pager (less), apparently with '--chop-long-lines'.
    #
    # A trailing hash is interpreted as options and passed to
    # sudo. Since systemctl returns non-zero for a variety of normal
    # conditions, the :accept option can be passed to account for
    # these, as well as :error => false.
    def systemctl_status( *units )
      opts = units.last.is_a?( Hash ) && units.pop || {}
      sudo( <<-SH, opts )
        systemctl status #{units.join ' '} | sed -E -e 's/\\s+$//'
      SH
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
