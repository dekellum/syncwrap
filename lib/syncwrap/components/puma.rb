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
require 'syncwrap/change_key_listener'
require 'syncwrap/systemd_service'

module SyncWrap

  # Provision to install and start/restart a Puma HTTP server
  # instance, optionally triggered by a state change key. Systemd
  # service and socket units are supported.
  #
  # Host component dependencies:  <Distro>?, RunUser, <ruby>, SourceTree?
  class Puma < Component
    include ChangeKeyListener
    include SystemDService

    # Puma version to install and run, if set. Otherwise assume puma
    # is bundled with the application (i.e. Bundle) and use bin stubs
    # to run.  (Default: nil; Example: 3.3.0)
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
        daemon: !foreground? }.merge( @puma_flags )
    end

    protected

    # Should Puma be restarted even when there were no source bundle
    # changes? (Default: false)
    attr_writer :always_restart

    def always_restart?
      @always_restart
    end

    # Deprecated
    alias :systemd_unit :systemd_service

    # Deprecated
    alias :systemd_unit= :systemd_service=

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
      @rack_path = nil
      @puma_flags = {}
      super
      if systemd_socket && !systemd_service
        raise "Puma#systemd_service is required when #systemd_socket is specified"
      end
    end

    def install
      if puma_version
        gem_install( 'puma', version: puma_version )
      end

      if systemd_service
        install_units( always_restart? || change_key_changes? )
      else
        rudo( "( cd #{rack_path}", close: ')' ) do
          rudo( "if [ -f puma.state -a -e control ]; then",
                close: bare_else_start ) do
            if always_restart? || change_key_changes?
              bare_restart
            else
              rudo 'true' #no-op
            end
          end
        end
        nil
      end
    end

    def start
      if systemd_service
        super
      else
        bare_start
      end
    end

    def restart( *args )
      if systemd_service
        super
      else
        bare_restart
      end
    end

    def stop
      if systemd_service
        super
      else
        bare_stop
      end
    end

    def status
      if systemd_service
        super
      else
        bare_status
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

    def bare_status
      rudo( ( pumactl_command + %w[ --state puma.state status ] ).join( ' ' ) )
    end

    def bare_start
      rudo( "cd #{rack_path} && #{puma_start_command}" )
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

    def rput_unit_files
      c = rput( src_for_systemd_service,
                "/etc/systemd/system/#{systemd_service}", user: :root )
      if systemd_socket
        c += rput( src_for_systemd_socket,
                   "/etc/systemd/system/#{systemd_socket}", user: :root )
      end
      c
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

  end
end
