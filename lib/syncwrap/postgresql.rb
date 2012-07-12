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

require 'syncwrap/base'

module SyncWrap::PostgreSQL

  def initialize
    super
  end

  # Update PostgreSQL config files from local etc
  def pg_configure
    rput( 'etc/postgresql/9.1/main/', :user => 'postgres:postgres' )
  end

  def pg_install
    dist_install 'postgresql'
  end

  def pg_start
    dist_service( 'postgresql', 'start' )
  end

  def pg_stop
    dist_service( 'postgresql', 'stop' )
  end

  def pg_adjust_sysctl
    rput( 'etc/sysctl.d/61-postgresql-shm.conf', :user => 'root' )
    sudo "sysctl -p /etc/sysctl.d/61-postgresql-shm.conf"
  end

  module Ubuntu
    include SyncWrap::PostgreSQL

    def initialize
      super
    end

    # Install PostgreSQL from 'pitti' apt repo
    # https://launchpad.net/~pitti/+archive/postgresql
    def pg_install
      # FIXME: No longer needed on precise?
      sudo <<-SH
        add-apt-repository ppa:pitti/postgresql
        apt-get update
      SH
      super
    end

  end

  module EC2
    include SyncWrap::PostgreSQL

    def initialize
      super
    end

    def pg_relocate
      sudo <<-SH
        mkdir -p /mnt/var/postgresql/
        mv /var/lib/postgresql/9.1 /mnt/var/postgresql/
      SH
    end

  end

end
