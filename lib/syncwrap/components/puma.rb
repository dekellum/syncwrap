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

require 'syncwrap/components/source_bundle'

module SyncWrap

  # A specialized SourceBundle that starts or restarts the Puma HTTP
  # server as needed, based on the source config.ru.  Puma itself
  # should be declared as a dependency in the source bundle Gemfile.
  #
  # Host component dependencies: RunUser
  class Puma < SourceBundle

    # Should Puma be restarted even when there were no source bundle
    # changes? (Default: false)
    attr_writer :always_restart

    def always_restart?
      @always_restart
    end

    def initialize( opts = {} )
      @always_restart = false
      super
    end

    def install
      changes = super
      rudo( "( cd #{remote_source_path}", close: ')' ) do
        rudo( "if [ -f puma.state -a -e control ]; then", close: else_start ) do
          if changes.empty? && !always_restart?
            rudo 'true' #no-op
          else
            restart
          end
        end
      end
      changes
    end

    protected

    def restart
      rudo <<-SH
        bin/pumactl --state puma.state restart
      SH
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

      "bin/puma " + args.compact.join( ' ' )
    end

    def puma_args
      { dir: remote_source_path,
        pidfile: "#{remote_source_path}/puma.pid",
        state: "#{remote_source_path}/puma.state",
        control: "unix://#{remote_source_path}/control",
        environment: "production",
        port: 5874,
        daemon: true }
    end

    def key_to_arg( key )
      '--' + key.to_s.gsub( /_/, '-' )
    end

  end
end
