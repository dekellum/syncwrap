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
space.use_provider( AmazonEC2 )

profile( :default,
         region: 'us-west-2',
         instance_type: 't2.small',
         vpc: 'vpc-58654f3d',          #default vpc
         subnet_id: 'subnet-7b700522', #default vpc
         key_name: 'dek-key-pair-1' )

# Centos 7.1 2014-09-29 HVM EBS 64 us-west-2
# https://aws.amazon.com/marketplace/pp/B00O7WM7QW
profile( :centos,
         ebs_mounts: :sdf_p,
         image_id: 'ami-c7d092f7',
         user_data: UserData.no_tty_sudoer( 'centos' ),
         roles: [ :centos ] )

# Debian 8.1 "Jessie" HVM EBS 64 us-west-2
# https://wiki.debian.org/Cloud/AmazonEC2Image/Jessie
profile( :debian,
         ebs_mounts: :sdf_p,
         image_id: 'ami-818eb7b1',
         user_data: UserData.no_tty_sudoer( 'admin' ),
         roles: [ :debian ] )

role( :amazon_linux,
      Users.new( ssh_user: 'ec2-user', ssh_user_pem: 'private/key.pem' ),
      RHEL.new,
      Network.new )

role( :centos,
      Users.new( ssh_user: 'centos', ssh_user_pem: 'private/key.pem' ),
      CentOS.new( centos_version: '7.1' ),
      Network.new )

role( :debian,
      Debian.new( debian_version: '8.1' ),
      Users.new( ssh_user: 'admin', ssh_user_pem: 'private/key.pem' ),
      Network.new )

role( :cruby,
      CRubyVM.new )

role( :postgres,
      PostgreSQL.new( commit_delay: 10_000,
                      synchronous_commit: :off,
                      shared_buffers: '256MB',
                      work_mem: '128MB',
                      maintenance_work_mem: '128MB',
                      max_stack_depth: '4MB',
                      effective_io_concurrency: 3,
                      network_access: :trust,
                      local_network_access: :trust ) )

role( :jruby,
      RunUser.new,
      OpenJDK.new,
      JRubyVM.new,
      Hashdot.new,
      BundlerGem.new( bundler_version: '1.9.9' ),
      TarpitGem.new( user_install: true ),
      Iyyov.new )

# Generated Hosts:
