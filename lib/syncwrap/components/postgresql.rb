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

# For distro class comparison only (pre-load for safety)
require 'syncwrap/components/rhel'
require 'syncwrap/components/ubuntu'

# Provisions for install and configuration of PostgreSQL
module SyncWrap

  class PostgreSQL < Component

    # Location of postgresql data dir
    attr_accessor :pg_data_dir

    def initialize( opts = {} )
      @pg_data_dir = '/pg/data'
      super
    end

    def pg_deploy_config
      case distro
      when RHEL
        'postgresql/rhel'
      when Ubuntu
        'postgresql/ubuntu'
      else
        raise ContextError, "Distro #{distro.class.name} not supported"
      end
    end

    def pg_config_dir
      case distro
      when RHEL
        pg_data_dir
      when Ubuntu
        '/etc/postgresql/9.1/main'
      else
        raise ContextError, "Distro #{distro.class.name} not supported"
      end
    end

    def install
      package_install
      changes = setup_data_dir
      changes += pg_configure
      if changes.empty?
        pg_start
      else
        pg_restart
      end
    end

    def package_install
      dist_install 'postgresql'
      if distro.is_a?( Ubuntu )
        pg_stop
        rput( 'etc/sysctl.d/61-postgresql-shm.conf', :user => 'root' )
        sudo "sysctl -p /etc/sysctl.d/61-postgresql-shm.conf"
      end
    end

    def setup_data_dir
      changes = []

      case distro

      when RHEL
        unless pg_data_dir == '/var/lib/pgsql9/data'
          changes = rput( 'etc/sysconfig/pgsql/postgresql', :user => 'root' )
        end

        sudo( "if [ ! -d '#{pg_data_dir}/base' ]; then", close: "fi" ) do
          unless pg_data_dir == '/var/lib/pgsql9/data'
            # (Per Amazon Linux)
            # Install PGDATA var override for init.d/postgresql
            sudo <<-SH
              mkdir -p #{pg_data_dir}
              chown postgres:postgres #{pg_data_dir}
              chmod 700 #{pg_data_dir}
            SH
          end
          dist_service( 'postgresql', 'initdb' )
        end

      when Ubuntu
        unless pg_data_dir == '/var/lib/postgresql/9.1/main'
          sudo <<-SH
            mkdir -p #{pg_data_dir}
            chown postgres:postgres #{pg_data_dir}
            chmod 700 #{pg_data_dir}
            mv #{pg_default_data_dir}/* #{pg_data_dir}/
          SH
        end
      else
        raise ContextError, "Distro #{distro.class.name} not supported"
      end

      changes
    end

    # Update PostgreSQL config files
    def pg_configure
      changes = rput( "#{pg_deploy_config}/", pg_config_dir, :user => 'postgres' )
      if !changes.empty? && pg_config_dir == pg_data_dir
        sudo( "chmod 700 #{pg_data_dir}" )
      end
      changes
    end

    def pg_start
      dist_service( 'postgresql', 'start' )
    end

    def pg_restart
      dist_service( 'postgresql', 'restart' )
    end

    def pg_stop
      dist_service( 'postgresql', 'stop' )
    end

  end

end
