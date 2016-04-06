#--
# Copyright (c) 2011-2016 David Kellum
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

  # Provision to install and start/restart a Puma HTTP server
  # instance, optionally triggered by a state change key. Systemd
  # service and socket units are supported.
  #
  # Host component dependencies:  <Distro>?, RunUser, <ruby>, SourceTree?
  class Puma < Component

    # Puma version to install and run, if set. Otherwise assume puma
    # is bundled with the application (i.e. Bundle) and use bin stubs
    # to run.  (Default: nil; Example: 2.9.0)
    attr_accessor :puma_version

    # Path to the application/configuration directory which
    # contains the config.ru.
    # (Default: SourceTree#remote_source_path)
    attr_writer :rack_path

    def rack_path
      @rack_path || remote_source_path
    end

    # Hash of puma command line flag overrides.
    # (Default: See #puma_flags)
    attr_writer :puma_flags

    def puma_flags
      { dir: rack_path,
        pidfile: "#{rack_path}/puma.pid",
        state: "#{rack_path}/puma.state",
        control: "unix://#{rack_path}/control",
        environment: "production",
        port: 5874,
        daemon: !foreground? }.merge( @puma_flags )
    end

    protected

    # An optional state key to check, indicating changes requiring
    # a Puma restart (Default: nil; Example: :source_tree)
    attr_accessor :change_key

    # Should Puma be restarted even when there were no source bundle
    # changes? (Default: false)
    attr_writer :always_restart

    def always_restart?
      @always_restart
    end

    # The name of the systemd service unit file to create for this
    # instance of puma. If specified, the name should include a
    # '.service' suffix. Will rput the same name (or .erb extended
    # template) under :sync_paths /etc/systemd/system, or the generic
    # puma.service at the same location if not found.
    # (Default: nil -> no service unit)
    attr_accessor :systemd_service

    # Deprecated
    alias :systemd_unit :systemd_service

    # Deprecated
    alias :systemd_unit= :systemd_service=

    # The name of the systemd socket unit file to create for this
    # instance of puma, for socket activation. If specified, the name
    # should include a '.socket' suffix and #systemd_service is also
    # required.  Will rput the same name (or .erb extended
    # template) under :sync_paths /etc/systemd/system, or the generic
    # puma.service at the same location if not found.
    # (Default: nil -> no socket unit)
    attr_accessor :systemd_socket

    # An array of ListenStream configuration values for
    # #systemd_socket. If a #puma_flags[:port] is specified, this
    # defaults to a single '0.0.0.0:port' stream. Otherwise this
    # setting is required if #systemd_socket is specified.
    attr_writer :listen_streams

    def listen_streams
      if @listen_streams
        @listen_streams
      elsif p = puma_flags[:port]
        [ "0.0.0.0:#{p}" ]
      else
        raise( "Neither #listen_streams nor #puma_flags[:port] specified" +
               " with Puma#systemd_socket" )
      end
    end

    public

    def initialize( opts = {} )
      @puma_version = nil
      @always_restart = false
      @change_key = nil
      @rack_path = nil
      @puma_flags = {}
      @systemd_service = nil
      @systemd_socket = nil
      @listen_streams = nil
      super
      if systemd_socket && !systemd_service
        raise "Puma#systemd_service is required when #systemd_socket is specified"
      end
    end

    def install
      if puma_version
        gem_install( 'puma', version: puma_version )
      end

      changes = change_key && state[ change_key ]

      if systemd_service
        serv_changes = rput( src_for_systemd_service,
                             "/etc/systemd/system/#{systemd_service}",
                             user: :root )

        sock_changes = if systemd_socket
                         rput( src_for_systemd_socket,
                               "/etc/systemd/system/#{systemd_socket}",
                               user: :root )
                       else
                         []
                       end

        if !serv_changes.empty? || !sock_changes.empty?
          systemctl( 'daemon-reload' )
          systemctl( 'enable', *systemd_units )
        end
        if( change_key.nil? || changes ||
            !serv_changes.empty? || !sock_changes.empty? || always_restart? )
          if !sock_changes.empty?
            systemctl( 'restart', *systemd_units )
          else
            systemctl( 'restart', systemd_service )
          end
        else
          systemctl( 'start', *systemd_units )
        end

        serv_changes + sock_changes
      else
        rudo( "( cd #{rack_path}", close: ')' ) do
          rudo( "if [ -f puma.state -a -e control ]; then",
                close: bare_else_start ) do
            if ( change_key && !changes ) && !always_restart?
              rudo 'true' #no-op
            else
              bare_restart
            end
          end
        end
        nil
      end
    end

    def puma_restart
      if systemd_service
        systemctl( 'restart', systemd_service )
      else
        bare_restart
      end
    end

    def puma_stop
      if systemd_service
        systemctl( 'stop', *systemd_units )
      else
        bare_stop
      end
    end

    protected

    # By default, runs in foreground if a systemd_service is specified.
    def foreground?
      !!systemd_service
    end

    def bare_restart
      rudo( ( pumactl_command + %w[ --state puma.state restart ] ).join( ' ' ) )
    end

    def bare_stop
      rudo( ( pumactl_command + %w[ --state puma.state stop ] ).join( ' ' ) )
    end

    def bare_else_start
      <<-SH
        else
          #{puma_start_command}
        fi
      SH
    end

    def puma_start_command
      args = puma_flags.map do |key,value|
        if value.is_a?( TrueClass )
          key_to_arg( key )
        elsif value.nil? || value.is_a?( FalseClass )
          nil
        else
          [ key_to_arg( key ), value && value.to_s ]
        end
      end
      ( puma_command + args.compact ).join( ' ' )
    end

    def puma_command
      if puma_version
        [ ruby_command, '-S', 'puma', "_#{puma_version}_" ]
      else
        [ File.expand_path( File.join( bundle_install_bin_stubs, "puma" ),
                            rack_path ) ]
      end
    end

    def pumactl_command
      if puma_version
        [ ruby_command, '-S', 'pumactl', "_#{puma_version}_" ]
      else
        [ File.expand_path( File.join( bundle_install_bin_stubs, "pumactl" ),
                            rack_path ) ]
      end
    end

    def key_to_arg( key )
      '--' + key.to_s.gsub( /_/, '-' )
    end

    def src_for_systemd_service
      s = "/etc/systemd/system/#{systemd_service}"
      unless find_source( s )
        s = '/etc/systemd/system/puma.service'
      end
      s
    end

    def src_for_systemd_socket
      s = "/etc/systemd/system/#{systemd_socket}"
      unless find_source( s )
        s = '/etc/systemd/system/puma.socket'
      end
      s
    end

    def systemd_units
      [systemd_socket, systemd_service].compact
    end

  end
end
