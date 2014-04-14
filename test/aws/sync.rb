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

include SyncWrap

space.prepend_sync_path
space.use_provider( AmazonEC2 )

profile( :default,
         image_id: "ami-ccf297fc", #Amazon Linux 2013.09.2 EBS 64 us-west-2
         region: 'us-west-2',
         user_data: :ec2_user_sudo,
         key_name: 'dek-key-pair-1',
         roles: [ :amazon_linux ] )

profile( :basic,
         default_name: "basic",
         instance_type: 'm3.medium',
         roles: [ :jruby_stack ] )

profile( :postgres,
         default_name: "pg",
         instance_type: 'm3.medium',
         ebs_volumes: 4,
         ebs_volume_options: { size: 2 }, #gb
         roles: [ :postgres ] )

profile( :cruby,
         instance_type: 'm3.medium',
         roles: [ :cruby ] )

role( :amazon_linux,
      Users.new( ssh_user: 'ec2-user', ssh_user_pem: 'private/key.pem' ),
      RHEL.new,
      Network.new )

role( :cruby,
      CRubyVM.new )

role( :postgres,
      MDRaid.new( raw_devices: 4,
                  lvm_volumes: [ [1.0, '/pg'] ],
                  mount_opts: %w[ defaults auto noatime nodiratime
                                  data=writeback barrier=0 ] ),
      PostgreSQL.new( pg_data_dir: '/pg/data',
                      checkpoint_segments: 16,
                      commit_delay: 10_000,
                      synchronous_commit: :off,
                      shared_buffers: '256MB',
                      work_mem: '128MB',
                      maintenance_work_mem: '128MB',
                      max_stack_depth: '4MB',
                      effective_io_concurrency: 4,
                      network_access: :trust ) )

role( :jruby_stack,
      RunUser.new,
      OpenJDK.new,
      JRubyVM.new,
      Hashdot.new,
      Iyyov.new,
      Geminabox.new )

# Generated Hosts:
