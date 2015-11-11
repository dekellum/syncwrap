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

require 'syncwrap/component'
require 'syncwrap/version_support'

# For distro class comparison only (pre-load for safety)
require 'syncwrap/components/rhel'
require 'syncwrap/components/amazon_linux'
require 'syncwrap/components/debian'
require 'syncwrap/components/ubuntu'

module SyncWrap

  # Provisions for install and configuration of a \PostgreSQL server
  #
  # Host component dependencies: <Distro>
  #
  # Currently provided (sync/postgresql) configuration is \PostgreSQL
  # 9.x compatible.  You will need to provide your own complete
  # configuration for any other versions.
  #
  # Most distros provide reasonably updated \PostgreSQL 9.x in more
  # recent releases:
  #
  # * RHEL, CentOS 6: 8.4
  # * RHEL, CentOS 7: 9.2
  # * AmazonLinux 2013.03: 8.4 9.2
  # * AmazonLinux 2014.09: 8.4 9.2 9.3
  # * Debian 7: 9.1
  # * Ubuntu 14: 9.3
  #
  # The latest stable and beta packages can also be obtained via the
  # \PostgreSQL {Yum Repo}[http://yum.postgresql.org] or
  # {Apt Repo}[http://wiki.postgresql.org/wiki/Apt]. Create your own
  # repo component to install these repo's, then configure the
  # \PostgreSQL component accordingly for #pg_version,
  # #pg_default_data_dir, #package_names.
  #
  class PostgreSQL < Component
    include VersionSupport

    # \PostgreSQL _MAJOR.MINOR_ version to install. Since there are
    # multiple versions in use even for _default_ system packages across
    # distros, this should be set the same as the version that will
    # be installed via #package_names.
    # (Default: guess based on distro/version or '9.1')
    attr_writer :pg_version

    def pg_version
      ( @pg_version ||
        ( case distro
          when AmazonLinux
            '9.2' if version_gte?( amazon_version, [2013,3] )
          when RHEL
            '9.2' if version_gte?( rhel_version, [7] )
          when Ubuntu
            '9.3' if version_gte?( ubuntu_version, [14,4] )
          end
          ) ||
          '9.1' )
    end

    # Location of postgresql data (and possibly also config) directory.
    # (Default: #pg_default_data_dir)
    attr_accessor :pg_data_dir

    def pg_data_dir
      @pg_data_dir || pg_default_data_dir
    end

    protected

    # Deprecated
    alias :version :pg_version

    # Deprecated
    alias :version= :pg_version=

    protected :version, :version=

    # The _default_ data dir as used by the distro #package_names.
    # (Default: as per RHEL/Debian package conventions)
    attr_writer :pg_default_data_dir

    def pg_default_data_dir
      ( @pg_default_data_dir ||
        ( case distro
          when AmazonLinux
            '/var/lib/pgsql9/data'
          when RHEL
            if version_lt?( rhel_version, [7] )
              '/var/lib/pgsql9/data'
            end
          when Debian
            "/var/lib/postgresql/#{pg_version}/main"
          end ) ||
        '/var/lib/pgsql/data' )
    end

    # Configuration in the '/etc' directory root?
    # (Default: true on Debian only, per distro package conventions)
    attr_writer :pg_specify_etc_config

    def pg_specify_etc_config
      @pg_specify_etc_config || distro.is_a?( Debian )
    end

    # The package names, including \PostgreSQL server of the
    # desired version to install.
    # (Default: guess based on distro)
    attr_writer :package_names

    def package_names
      ( @package_names ||
        ( distro.is_a?( Debian ) && [ "postgresql-#{pg_version}" ] ) ||
        ( distro.is_a?( AmazonLinux ) &&
          ( ( version_gte?( amazon_version, [2014,9] ) && [ "postgresql92-server" ] ) ||
            [ "postgresql9-server" ] ) ) ||
        [ "postgresql-server" ] )
    end

    # The service name of the \PostgreSQL server to start
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

    # WAL log segments (16MB each)
    # Deprecated with PostgreSQL 9.5: Use min/max_wal_size instead
    attr_writer :checkpoint_segments

    def checkpoint_segments
      @checkpoint_segments || ( version_lt?(pg_version, [9,5]) ? 3 : 5 )
    end

    # Minimum WAL size as string with units
    # Default: PG <9.5: "48MB"; PG 9.5+: "80MB"
    attr_writer :min_wal_size

    def min_wal_size
      @min_wal_size || "#{ checkpoint_segments * 16 }MB"
    end

    # Maximum WAL size as string with units.
    # (Default: unset, PG Default: '1GB')
    attr_writer :max_wal_size

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

    # Method used in pg_hba.conf for local (unix socket) access
    # (PG Default: :peer)
    attr_accessor :local_access

    # Method used in pg_hba.conf for local network access. Note
    # that :peer does not work here.
    # (PG Default: :md5)
    attr_accessor :local_network_access

    # Method used in pg_hba.conf for network access
    # :md5 is a common value for password auth.
    # If truthy, will also set listen_address = '*' in postgresql.conf
    # (PG Default: false -> no access)
    attr_accessor :network_access

    # IPv4 address mask for #network_access
    # (PG Default: nil -> no IPv4 access)
    attr_accessor :network_v4_mask

    # IPv6 address mask for #network_access
    # (PG Default: nil -> no IPv4 access)
    attr_accessor :network_v6_mask

    # Kernel SHMMAX (Shared Memory Maximum) setting to apply.
    # Note that PostgreSQL 9.3 uses mmap and should not need this.
    # Currently this only set on Debian distros.
    # (Default: 300MB if #pg_version < 9.3)
    attr_writer :shared_memory_max

    # A command pattern to initialize the database on first
    # install. This is used on systemd distro's only.  The pattern is
    # expanded using #pg_data_dir as the first (optional)
    # replacement. The command is run by the postgres user.
    #
    # (Default: "/usr/bin/initdb %s")
    attr_accessor :initdb_cmd

    def shared_memory_max
      @shared_memory_max || ( version_lt?(pg_version, [9,3]) && 300_000_000 )
    end

    def pg_config_dir
      case distro
      when RHEL
        pg_data_dir
      when Debian
        "/etc/postgresql/#{pg_version}/main"
      else
        raise ContextError, "Distro #{distro.class.name} not supported"
      end
    end

    public

    def initialize( opts = {} )
      @pg_data_dir = nil
      @pg_default_data_dir = nil
      @pg_version = nil
      @package_names = nil
      @service_name = 'postgresql'
      @synchronous_commit = :on
      @commit_delay = 0
      @checkpoint_segments = nil
      @min_wal_size = nil
      @max_wal_size = nil
      @shared_buffers = '256MB'
      @work_mem = '128MB'
      @maintenance_work_mem = '128MB'
      @max_stack_depth = '4MB'
      @effective_io_concurrency = 1
      @local_access = :peer
      @local_network_access = :md5
      @network_access = false
      @network_v4_mask = nil
      @network_v6_mask = nil
      @shared_memory_max = nil
      @initdb_cmd = "/usr/bin/initdb %s"
      super
    end

    # Calls in order: #package_install, #setup_data_dir, and
    # #pg_configure then ensures the server is running (via #pg_start) or
    # is restarted (via #pg_restart) if there were configuration changes.
    def install
      package_install
      changes = setup_data_dir
      changes += pg_configure
      if changes.empty?
        pg_start
      else
        pg_restart
      end
      changes
    end

    # Install the #package_names. In the Debian case, also install any
    # #shared_memory_max adjustment and stops the server for subsequent
    # reconfigure or data relocation.
    def package_install
      dist_install( *package_names )
      if distro.is_a?( Debian )
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
          pg_initdb
        end

      when Debian
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

    def pg_initdb
      if distro.systemd?
        if initdb_cmd
          sudo <<-SH
            su postgres -c '#{initdb_cmd % [ pg_data_dir ]}'
          SH
        else
          raise ContextError, "PostgreSQL#initdb_cmd is required with systemd"
        end
      else
        dist_service( service_name, 'initdb' )
      end
    end

    # Update the \PostgreSQL configuration files
    def pg_configure
      files  = %w[ pg_hba.conf pg_ident.conf postgresql.conf ]
      files += %w[ environment pg_ctl.conf ] if distro.is_a?( Debian )
      files  = files.map { |f| File.join( 'postgresql', f ) }
      rput( *files, pg_config_dir, user: 'postgres' )
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
