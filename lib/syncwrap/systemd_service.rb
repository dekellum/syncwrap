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

module SyncWrap

  # Support module for components which install SystemD
  # services. Provide unit file installation with `systemctl` calls,
  # and also provides standard #enable, #start, #status, #restart,
  # #stop, and #disable commands for use in the CLI.
  #
  # Host component dependencies: <Distro>
  module SystemDService

    protected

    # The name of a systemd service unit file to create/rput. The name
    # should include a ".service" suffix. Will rput the same name (or
    # .erb extended template) under :sync_paths /etc/systemd/system.
    # (Required for use of public interface)
    attr_accessor :systemd_service

    # The name of the systemd socket unit file to create/rput for
    # socket activation. If specified, the name should include a
    # ".socket" suffix. Will rput the same name (or .erb extended
    # template) under :sync_paths /etc/systemd/system.
    attr_accessor :systemd_socket

    # An array of ListenStream configuration values for #systemd_socket
    # (Default: nil -> unspecified and will raise if accessed)
    attr_writer :listen_streams

    def listen_streams
      @listen_streams or raise "#{self.class.name}#listen_streams not specified"
    end

    def initialize( opts = {} )
      @systemd_service = nil
      @systemd_socket = nil
      @listen_streams = nil
      super
    end

    public

    # Install the systemd units files by #rput_unit_files, detecting
    # changes and performs `systemctl` daemon-reload, (re-)enable, and
    # #restart or #start as required. If restart_required evaluates to
    # true, for example given other external changes, a #restart is
    # mandated.
    def install_units( restart_required = false )
      require_systemd_service!
      units_d = rput_unit_files

      sock_d = systemd_socket &&
               units_d.find { |_,f| File.basename( f ) == systemd_socket }

      if !units_d.empty?
        systemctl( 'daemon-reload' )
        systemctl( 'reenable', *systemd_units )
      end

      if ( restart_required || !units_d.empty? )
        restart( with_socket: !!sock_d )
      else
        start
      end

      units_d
    end

    # Start all #systemd_units.
    def start
      require_systemd_service!
      systemctl( 'start', *systemd_units )
    end

    # Restart the service. If option :with_socket is passed as true,
    # restart all #systemd_units which includes #systemd_socket if
    # present.
    def restart( opts = {} )
      require_systemd_service!
      if opts[ :with_socket ]
        systemctl( 'restart', *systemd_units )
      else
        systemctl( 'restart', systemd_service )
      end
    end

    # Stop all #systemd_units.
    def stop
      require_systemd_service!
      systemctl( 'stop', *systemd_units )
    end

    # Disable all #systemd_units.
    def disable
      require_systemd_service!
      systemctl( 'disable', *systemd_units )
    end

    # Enable all #systemd_units.
    def enable
      require_systemd_service!
      systemctl( 'enable', *systemd_units )
    end

    # Output status of #systemd_units (useful via CLI with --verbose).
    # Exit codes 0-3 are accepted from `systemctl`, since these will
    # be returned in normal operational contexts, for example, when
    # services are intentionally and manually stopped. Exit on error
    # is also disabled, which may be relevent for merged commands.
    def status
      require_systemd_service!
      systemctl_status( *systemd_units, error: false, accept: [0,1,2,3] )
    end

    protected

    # Perform rput of systemd unit files and return changes
    # array. This can be overridden, for example to use system
    # provided units (no-op and return `[]`) or for additional "drop-in"
    # config files (e.g. foo.service.d/overrides.conf).  Any changes
    # signal that the service (or if included in changes, the socket)
    # should be restarted.
    def rput_unit_files
      srcs = systemd_units.map { |u| "/etc/systemd/system/" + u }
      rput( *srcs, "/etc/systemd/system/", user: :root )
    end

    # Return Array of the unit names that were specified (not nil)
    # via #systemd_service and #systemd_socket.
    def systemd_units
      [systemd_socket, systemd_service].compact
    end

    # Raise if systemd_service not specified.
    def require_systemd_service!
      raise "#{self.class.name}#systemd_service not set" unless systemd_service
    end

  end

end
