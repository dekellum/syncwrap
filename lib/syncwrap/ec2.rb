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

  def initialize
    super
  end

  # http://serverfault.com/questions/317009/convert-file-system-format-on-aws-ec2-ephemeral-storage-disk-from-ext3-to-ex4t
  def reformat_mnt_as_ext4!
    #FIXME: Should have a safety test to avoid data loss here!
    sudo <<-SH
      umount /mnt
      mkfs -t ext4 /dev/xvda2
      mount  /mnt
    SH
  end

end
