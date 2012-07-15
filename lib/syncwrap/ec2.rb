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

require 'syncwrap/common'

# Provisions for common Amazon EC2 image tasks.
module SyncWrap::EC2
  include SyncWrap::Common

  # The device name of the EBS device mounted on /mnt
  # (default: 'xvdb')
  attr_accessor :ec2_ebs_mnt_device

  def initialize
    super

    @ec2_ebs_mnt_device = 'xvdb'
  end

  # WARNING: Destructive if run!
  # Re-mkfs /mnt partition as ext4 if its ec2_ebs_mnt_device and is
  # currently ext3
  def ec2_reformat_mnt_as_ext4
    rc = exec_conditional do
      run "mount | grep '/dev/#{ec2_ebs_mnt_device} on /mnt'"
    end
    raise "Device /dev/#{ec2_ebs_mnt_device} not mounted on /mnt" unless rc == 0

    rc = exec_conditional do
      run "mount | grep '/dev/#{ec2_ebs_mnt_device} on /mnt type ext3'"
    end
    ec2_reformat_mnt_as_ext4! if rc == 0
  end

  # WARNING: Destructive!
  # Re-mkfs /mnt partition as ext4
  # See: http://serverfault.com/questions/317009
  def ec2_reformat_mnt_as_ext4!
    sudo <<-SH
      umount /mnt
      mkfs -t ext4 /dev/#{ec2_ebs_mnt_device}
      mount  /mnt
    SH
  end

end
