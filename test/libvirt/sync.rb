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

include SyncWrap

space.prepend_sync_path
space.use_provider( Libvirt )

options( check_install: true )

profile( :default,
         disk: { root: { delete_on_terminate: true } },
         roles: [ :libvirt ] )

profile( :debian,
         image_name: 'debian-8',
         roles: [ :debian, :common ] )

profile( :ubuntu,
         image_name: 'ubuntu-14.04',
         roles: [ :ubuntu, :common ] )

profile( :centos,
         image_name: 'centos-7',
         roles: [ :centos, :common ] )

role( :libvirt )

role( :ubuntu,
      Ubuntu.new( ubuntu_version: '14.04' ) )

role( :debian,
      Debian.new( debian_version: '8.2' ) )

role( :centos,
      CentOS.new( centos_version: '7.1' ) )

role( :common,
      Users.new( ssh_user: 'syncwrap', ssh_user_pem: 'private/syncwrap.pem' ),
      Network.new( dns_search: 'gravitext.com' ),
      EtcHosts.new )

role( :cruby,
      CRubyVM.new )

role( :ubuntu_postgres,
      PostgreSQL.new )

role( :debian_postgres,
      PostgreSQL.new )

role( :centos_postgres,
      PostgreSQL.new( pg_default_data_dir: '/var/lib/pgsql/data' ) )

role( :jruby,
      RunUser.new,
      OpenJDK.new,
      JRubyVM.new,
      Hashdot.new,
      Iyyov.new,
      Geminabox.new )

# Generated Hosts:
