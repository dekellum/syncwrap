# -*- ruby -*-

#--
# Copyright (c) 2011-2012 David Kellum
#
# Licensed under the Apache License, Version 2.0 (the "License"); you
# may not use this file except in compliance with the License.  You
# may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.  See the License for the specific language governing
# permissions and limitations under the License.
#++

desc "* Combined Full PostgreSQL Deployment"
task :pg_deploy => [ :mnt_reformat_ext4,
                     :pg_install,
                     :pg_stop,
                     :pg_relocate,
                     :pg_configure,
                     :pg_start ]

desc "Reformat /mnt partition as ext4 (WARNING!)"
# http://serverfault.com/questions/317009/convert-file-system-format-on-aws-ec2-ephemeral-storage-disk-from-ext3-to-ext4
remote_task :mnt_reformat_ext4 do
  #FIXME: Should have a safety test to avoid data loss here!
  sudo "umount /mnt"
  sudo "mkfs -t ext4 /dev/xvda2"
  sudo "mount  /mnt"
end

desc "Update PostgreSQL config files from local ./etc"
remote_task :pg_configure do
  run "rm -rf /tmp/pg.conf" #FIXME: Redundant?
  run "mkdir /tmp/pg.conf"
  rput( Dir[ 'etc/postgresql/9.1/main/*.conf' ], '/tmp/pg.conf' )
  sudo "mv -bf /tmp/pg.conf/*.conf /etc/postgresql/9.1/main/"
  run "rm -rf /tmp/pg.conf"
  sudo "chown postgres:postgres /etc/postgresql/9.1/main/*.conf"
end

desc "Install PostgreSQL from 'pitti' apt repo"
# https://launchpad.net/~pitti/+archive/postgresql
remote_task :pg_install do
  sudo "add-apt-repository ppa:pitti/postgresql"
  sudo "apt-get update"
  sudo "apt-get -yq install postgresql" # FIXME: -qq (quiet-er)
end

desc "Move PostgreSQL data template to /mnt"
remote_task :pg_relocate do
  sudo "mkdir -p /mnt/postgresql/"
  sudo "mv /var/lib/postgresql/9.1 /mnt/postgresql/"
end

desc "Start PostgreSQL service"
remote_task :pg_start do
  sudo "sysctl -w kernel.shmmax=300000000" #FIXME /etc/sysctl.conf also?
  sudo "service postgresql start"
end

desc "Stop PostgreSQL service"
remote_task :pg_stop do
  sudo "service postgresql stop"
end

desc "Purge PostgreSQL install (i.e. for testing)"
remote_task :pg_purge do
  sudo( "aptitude -y purge postgresql postgresql-8.4 postgresql-9.1" +
        "postgresql-client-9.1 postgresql-client-common postgresql-common" )
end
