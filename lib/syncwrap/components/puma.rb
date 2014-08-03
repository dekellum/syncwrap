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

  # Provision to install, start/restart a Puma HTTP
  # server, optionally triggered by a state change key.
  #
  # Host component dependencies: RunUser, <ruby>
  class Puma < Component

    # Puma version to install/run, if set. Otherwise assume puma is
    # bundled with the application (i.e. Bundle) and use bin stubs to
    # run.  (Default: nil; Example: 2.9.0)
    attr_accessor :puma_version

    # An optional state key to check, indicating changes requiring
    # a Puma restart (Default: nil; Example: :source_tree)
    attr_accessor :change_key

    # Path to the application config.ru
    # (Default: SourceTree#remote_source_path)
    attr_writer :rack_path

    def rack_path
      @rack_path || remote_source_path
    end

    # Should Puma be restarted even when there were no source bundle
    # changes? (Default: false)
    attr_writer :always_restart

    def always_restart?
      @always_restart
    end

    def initialize( opts = {} )
      @puma_version = nil
      @always_restart = false
      @change_key = nil
      @rack_path = nil
      super
    end

    def install
      if puma_version
        gem_install( 'puma', version: puma_version )
      end

      changes = change_key && state[ change_key ]
      rudo( "( cd #{rack_path}", close: ')' ) do
        rudo( "if [ -f puma.state -a -e control ]; then", close: else_start ) do
          if ( change_key && !changes ) && !always_restart?
            rudo 'true' #no-op
          else
            restart
          end
        end
      end
      nil
    end

    protected

    def restart
      rudo( ( pumactl_command + %w[ --state puma.state restart ] ).join( ' ' ) )
    end

    def else_start
      <<-SH
        else
          #{puma_start_command}
        fi
      SH
    end

    def puma_start_command
      args = puma_args.map do |key,value|
        if value.is_a?( TrueClass )
          key_to_arg( key )
        elsif value.is_a?( FalseClass )
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
        [ "bin/puma" ]
      end
    end

    def pumactl_command
      if puma_version
        [ ruby_command, '-S', 'puma', "_#{puma_version}_" ]
      else
        [ "bin/pumactl" ]
      end
    end

    def puma_args
      { dir: rack_path,
        pidfile: "#{rack_path}/puma.pid",
        state: "#{rack_path}/puma.state",
        control: "unix://#{rack_path}/control",
        environment: "production",
        port: 5874,
        daemon: true }
    end

    def key_to_arg( key )
      '--' + key.to_s.gsub( /_/, '-' )
    end

  end
end
