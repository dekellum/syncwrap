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

require 'syncwrap/component'

module SyncWrap

  # Handles assembling mdraid (Linux Software RAID) arrays from
  # previously attached raw devices.
  class MDRaid < Component

    # A number, range, or array of raw device names. See #raw_devices
    # for interpretation.
    attr_accessor :raw_volumes

    # A table of [ slice, path (,name) ] rows where; slice is a
    # floating point ratio in range (0.0,1.0], path is the mount
    # point, and name is the lvm name, defaulting if omitted to the
    # last path element. The sum of all slice values in the table
    # should be 1.0.
    attr_accessor :lvm_volumes

    # An instance number, default 0. Increment if applying multiple.
    attr_accessor :instance

    def initialize( opts = {} )
      @raw_volumes = 0
      @lvm_volumes = [ [ 1.00, '/data' ] ]
      @instance = 0
      super
    end

    def raw_devices
      case raw_volumes
      when Integer
        raw_volumes.times.map { |i| "/dev/xvdh#{i+1}" }
      when Range
        raw_volumes.map { |i| "/dev/xvdh#{i+1}" }
      when Array
        raw_volumes
      end
    end

    def install
      devs = raw_devices
      return if devs.empty? || lvm_volumes.empty?

      first_path = lvm_volumes.first[1]
      md = "/dev/md#{instance}"
      vg = "vg#{instance}"

      sudo( "if [ ! -d #{first_path} ]; then", close: "fi" ) do
        dist_install( "mdadm", "lvm2", minimal: true )
        sudo <<-SH
          mdadm --create #{md} --level=10 --chunk=256 \
            --raid-devices=#{devs.count} #{devs.join ' '}
          echo "DEVICE #{devs.join ' '}" > /etc/mdadm.conf
          mdadm --detail --scan >> /etc/mdadm.conf
        SH

        devs.each do |d|
          sudo "blockdev --setra 128 #{d}"
        end

        sudo <<-SH
          blockdev --setra 128 #{md}
          dd if=/dev/zero of=#{md} bs=512 count=1
          pvcreate #{md}
          vgcreate #{vg} #{md}
        SH

        lvm_volumes.each do |slice, path, name|
          name ||= File.basename( path )
          create_lvolume( slice, path, name )
        end
      end
    end

    def create_lvolume( slice, path, name )
      vg = "vg#{instance}"
      sudo <<-SH
        lvcreate -l #{(slice * 100).round}%vg -n #{name} #{vg}
        mke2fs -t ext4 -F /dev/#{vg}/#{name}
        if [ -d #{path} ]; then
          rm -rf #{path}
        fi
        mkdir -p #{path}
        echo '/dev/#{vg}/#{name} #{path} ext4 defaults,auto,noatime,noexec 0 0' \
          >> /etc/fstab
        mount #{path}
      SH
    end

  end

end
