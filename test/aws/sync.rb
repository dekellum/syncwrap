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

ec2 = AmazonEC2.new( space )

ec2.profile( :basic,
             default_name: "basic",
             image_id: "ami-ccf297fc", #Amazon Linux 2013.09.2 EBS 64 us-west-2
             region: 'us-west-2',
             user_data: :ec2_user_sudo,
             instance_type: 'm1.medium',
             key_name: 'dek-key-pair-1',
             roles: [ :amazon_linux, :jruby_stack ] )

role( :amazon_linux,
      Users.new( ssh_user: 'ec2-user', ssh_user_pem: 'private/key.pem' ),
      RHEL.new,
      Network.new )

role( :jruby_stack,
      RunUser.new,
      OpenJDK.new,
      JRubyVM.new,
      Hashdot.new,
      Iyyov.new,
      Geminabox.new )

# Generated Hosts:
