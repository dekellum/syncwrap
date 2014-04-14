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

module SyncWrap

  # Provisions for install and configuration of PostgreSQL
  #
  # Host component dependencies: <Distro>
  class PostgreSQL < Component

    public

    # Location of postgresql data dir
    attr_accessor :pg_data_dir

    # (default: '9.1')
    attr_accessor :version

    def version_a
      @version.split('.').map( &:to_i )
    end

    protected

    # The distro default data dir (set if known to be different than
    # distro-specific default, nil -> computed in accessor)
    attr_writer :pg_default_data_dir

    # Configuration in '/etc/* root? (Default: true on Ubuntu only)
    attr_writer :pg_specify_etc_config

    def pg_specify_etc_config
      @pg_specify_etc_config || distro.is_a?( Ubuntu )
    end

    # The package name containing PostgreSQL server of the desired version
    # (Default: Ubuntu: postgresql-/version/; RHEL: postgresql-server)
    attr_writer :package_name

    def package_name
      ( @package_name ||
        ( distro.is_a?( Ubuntu ) && "postgresql-#{version}" ) ||
        "postgresql-server" )
    end

    # Synchronization level for commit
    # :off may be desirable on high-latency storage (i.e. EBS), at
    # increased risk. (PG Default: :on)
    attr_accessor :synchronous_commit

    # Commit delay in microseconds
    # 10000 or more may be desirable on high-latency storage, at
    # increased risk. (PG Default: 0 -> none)
    attr_accessor :commit_delay

    # WAL log segments (16MB each) (PG Default: 3)
    attr_accessor :checkpoint_segments

    # Shared buffers (Default: '256MB' vs PG: '128MB')
    attr_accessor :shared_buffers

    # Work memory (Default: '128MB' vs PG: '1MB')
    attr_accessor :work_mem

    # Maintenance work memory (Default: '128MB' vs PG: '16MB')
    attr_accessor :maintenance_work_mem

    # Maximum stack depth (Default: '4MB' vs PG: '2MB')
    attr_accessor :max_stack_depth

    # Concurrent disk I/O operations
    # May help to use RAID device count or similar (PG Default: 1)
    attr_accessor :effective_io_concurrency

    # Method used in pg_hba.conf for network access
    # :md5 is a common values for password auth.
    # If truthy, will also set listen_address = '*' in postgresql.conf
    # (PG Default: false -> no access)
    attr_accessor :network_access

    # Kernel SHMMAX (Shared Memory Maximum) setting to apply.
    # Note that PostgreSQL 9.3 used mmap and likely doesn't need this.
    # Currently this is only set on Ubuntu (RHEL packages take care of
    # it?) (Default: 300MB if version < 9.3)
    attr_writer :shared_memory_max

    def shared_memory_max
      @shared_memory_max ||
        ( ( (version_a <=> [9,3]) < 0 ) && 300_000_000 )
    end

    public

    def initialize( opts = {} )
      @pg_data_dir = '/pg/data'
      @pg_default_data_dir = nil
      @version = '9.1'
      @package_name = nil
      @synchronous_commit = :on
      @commit_delay = 0
      @checkpoint_segments = 3
      @shared_buffers = '256MB'
      @work_mem = '128MB'
      @maintenance_work_mem = '128MB'
      @max_stack_depth = '4MB'
      @effective_io_concurrency = 1
      @network_access = false
      @shared_memory_max = nil
      super
    end

    def pg_default_data_dir
      @pg_default_data_dir ||
        case distro
        when RHEL
          '/var/lib/pgsql9/data'
        when Ubuntu
          "/var/lib/postgresql/#{version}/main"
        else
          raise ContextError, "Distro #{distro.class.name} not supported"
        end
    end

    def pg_config_dir
      case distro
      when RHEL
        pg_data_dir
      when Ubuntu
        "/etc/postgresql/#{version}/main"
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
      dist_install package_name
      if distro.is_a?( Ubuntu )
        pg_stop
        if shared_memory_max
          rput( 'etc/sysctl.d/61-postgresql-shm.conf', user: :root )
          sudo "sysctl -p /etc/sysctl.d/61-postgresql-shm.conf"
        end
      end
    end

    def setup_data_dir
      changes = []

      case distro

      when RHEL
        unless pg_data_dir == pg_default_data_dir
          changes = rput( 'etc/sysconfig/pgsql/postgresql', user: :root )
        end

        sudo( "if [ ! -d '#{pg_data_dir}/base' ]; then", close: "fi" ) do
          unless pg_data_dir == pg_default_data_dir
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
        unless pg_data_dir == pg_default_data_dir
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
      files = %w[ pg_hba.conf pg_ident.conf postgresql.conf ]
      files += %w[ environment pg_ctl.conf ] if distro.is_a?( Ubuntu )
      files = files.map { |f| File.join( 'postgresql', f ) }
      changes = rput( *files, pg_config_dir, user: 'postgres' )
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
