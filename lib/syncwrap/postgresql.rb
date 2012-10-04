#--
# Copyright (c) 2011-2012 David Kellum
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

require 'syncwrap/distro'
require 'syncwrap/ubuntu'
require 'syncwrap/rhel'

# Provisions for install and configuration of PostgreSQL
module SyncWrap::PostgreSQL
  include SyncWrap::Distro

  # Location of postgresql data dir (databases + config in default
  # case)
  attr_accessor :pg_data_dir

  # The stock distribution default data_dir. Difference with
  # pg_data_dir triggers additional install steps.
  attr_accessor :pg_default_data_dir

  # Local directory for configuration files (different by
  # distribution)
  attr_accessor :pg_deploy_config

  def initialize
    super
    @pg_data_dir = '/pg/data'
  end

  def pg_config_dir
    @pg_data_dir
  end

  def pg_install
    dist_install 'postgresql'
  end

  # Update PostgreSQL config files
  def pg_configure
    rput( "#{pg_deploy_config}/", pg_config_dir, :user => 'postgres' )
  end

  def pg_start
    dist_service( 'postgresql', 'start' )
  end

  def pg_stop
    dist_service( 'postgresql', 'stop' )
  end

  def self.included( base )
    if base.include?( SyncWrap::RHEL )
      base.send( :include, SyncWrap::PostgreSQL::RHEL )
    elsif base.include?( SyncWrap::Ubuntu )
      base.send( :include, SyncWrap::PostgreSQL::Ubuntu )
    end
  end

  module RHEL

    def initialize
      super
      #Per Amazon Linux 2012 3.3
      @pg_default_data_dir = '/var/lib/pgsql9/data'
      @pg_deploy_config = 'postgresql/rhel'
    end

    def pg_install
      super
      unless @pg_data_dir == @pg_default_data_dir
        # (Per Amazon Linux)
        # Install PGDATA var override for init.d/postgresql
        rput( 'etc/sysconfig/pgsql/postgresql', :user => 'root' )
      end
      dist_service( 'postgresql', 'initdb' )
    end

  end

  module Ubuntu

    def initialize
      super
      @pg_default_data_dir = '/var/lib/postgresql/9.1/main'
      @pg_deploy_config = 'postgresql/ubuntu'
    end

    def pg_install
      super
      pg_stop #Ubuntu does a start
      pg_adjust_sysctl
      pg_relocate unless @pg_data_dir == @pg_default_data_dir
    end

    def pg_config_dir
      "/etc/postgresql/9.1/main"
    end

    def pg_adjust_sysctl
      rput( 'etc/sysctl.d/61-postgresql-shm.conf', :user => 'root' )
      sudo "sysctl -p /etc/sysctl.d/61-postgresql-shm.conf"
    end

    # Move the data dir into its final location, since on Ubuntu the
    # package install does the initdb step
    def pg_relocate
      sudo <<-SH
        mkdir -p #{pg_data_dir}
        chown postgres:postgres #{pg_data_dir}
        mv #{pg_default_data_dir}/* #{pg_data_dir}/
      SH
    end

  end

end
