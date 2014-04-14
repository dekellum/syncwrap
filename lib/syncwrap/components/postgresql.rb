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

  # Provisions for install and configuration of a PostgreSQL server
  #
  # Host component dependencies: <Distro>
  class PostgreSQL < Component

    # PostgreSQL _MAJOR.MINOR_ version to install. Since there are
    # multiple versions in use even for _default_ system packages across
    # distros, this should be set the same as the version that will
    # be installed via #package_names.  (Default: '9.1')
    attr_accessor :version

    # Return #version as an Array of Integer values
    def version_a
      @version.split('.').map( &:to_i )
    end

    # Location of postgresql data (and possibly also config) directory.
    # (Default: #pg_default_data_dir)
    attr_accessor :pg_data_dir

    def pg_data_dir
      @pg_data_dir || pg_default_data_dir
    end

    protected

    # The _default_ data dir as used by the distro #package_names.
    # (Default: as per RHEL or Ubuntu distro packages)
    attr_writer :pg_default_data_dir

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

    # Configuration in the '/etc' directory root?
    # (Default: true on Ubuntu only, per distro package defaults)
    attr_writer :pg_specify_etc_config

    def pg_specify_etc_config
      @pg_specify_etc_config || distro.is_a?( Ubuntu )
    end

    # The package names, including PostgreSQL server of the
    # desired version to install.
    # (Default: Ubuntu: postgresql-_version_; RHEL: postgresql-server)
    attr_writer :package_names

    def package_names
      ( @package_names ||
        ( distro.is_a?( Ubuntu ) && [ "postgresql-#{version}" ] ) ||
        [ "postgresql-server" ] )
    end

    # The service name of the PostgreSQL server to start
    # (Default: 'postgresql' )
    attr_accessor :service_name

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
    # :md5 is a common value for password auth.
    # If truthy, will also set listen_address = '*' in postgresql.conf
    # (PG Default: false -> no access)
    attr_accessor :network_access

    # Kernel SHMMAX (Shared Memory Maximum) setting to apply.
    # Note that PostgreSQL 9.3 uses mmap and should not need this.
    # Currently this is only set on Ubuntu (RHEL packages take care of
    # it?) (Default: 300MB if #version < 9.3)
    attr_writer :shared_memory_max

    def shared_memory_max
      @shared_memory_max ||
        ( ( (version_a <=> [9,3]) < 0 ) && 300_000_000 )
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

    public

    def initialize( opts = {} )
      @pg_data_dir = nil
      @pg_default_data_dir = nil
      @version = '9.1'
      @package_names = nil
      @service_name = 'postgresql'
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

    # Install the #package_names. In the Ubuntu case, also install any
    # shared_memory_max adjustment and stop the server for subsequent
    # reconfigure or data relocation.
    def package_install
      dist_install( *package_names )
      if distro.is_a?( Ubuntu )
        pg_stop
        if shared_memory_max
          rput( 'etc/sysctl.d/61-postgresql-shm.conf', user: :root )
          sudo "sysctl -p /etc/sysctl.d/61-postgresql-shm.conf"
        end
      end
    end

    # Initialize or move the server data directory as per #pg_data_dir.
    def setup_data_dir
      changes = []

      case distro

      when RHEL
        unless pg_data_dir == pg_default_data_dir
          changes = rput( 'etc/sysconfig/pgsql/postgresql', user: :root )
        end

        sudo( "if [ ! -d '#{pg_data_dir}/base' ]; then", close: "fi" ) do
          sudo <<-SH
            mkdir -p #{pg_data_dir}
            chown postgres:postgres #{pg_data_dir}
            chmod 700 #{pg_data_dir}
          SH
          dist_service( service_name, 'initdb' )
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

    # Update the PostgreSQL configuration files
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

    # Start the server
    def pg_start
      dist_service( service_name, 'start' )
    end

    # Restart the server
    def pg_restart
      dist_service( service_name, 'restart' )
    end

    # Stop the server
    def pg_stop
      dist_service( service_name, 'stop' )
    end

  end

end
