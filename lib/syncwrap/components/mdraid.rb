#--
# Copyright (c) 2011-2016 David Kellum
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

  # Handles assembling mdraid (Linux Software RAID) arrays, lvm
  # volumes, creating and mounting filesystems from previously
  # attached raw devices.
  #
  # Host component dependencies: <Distro>
  class MDRaid < Component

    # An instance number used for mdraid and volume group
    # names. Increment this when applying multiple components of this
    # type to the same host.  Default: 0
    attr_accessor :instance

    # A number, range, or array of raw device names. See #raw_devices=
    # for interpretation.  Software raid is only used for >1 raw
    # device. Default: 0
    attr_reader :raw_devices

    # Block device read-ahead setting for the raw devices, in 512-byte
    # blocks. Default: 32
    attr_accessor :raw_read_ahead

    # Attempt to unmount and remove from fstab any existing mount of
    # the specified raw devices. _WARNING:_ this may increase the
    # danger of data loss!
    # (Default: false)
    attr_accessor :do_unmount

    # Numeric RAID level.
    # (Default: 10 if there are at least 4 raw devices, otherwise 0.)
    attr_accessor :raid_level

    # RAID md device read-ahead setting, in 512-byte blocks.
    # Default: 64
    attr_accessor :raid_read_ahead

    # RAID chunk size in KB
    # Default: 256
    attr_accessor :raid_chunk

    # A table of [ slice, path (,name) ] rows where; slice is a
    # Numeric in range (0.0..1.0), path is the mount point, and name
    # is the lvm name, defaulting if omitted to the last path
    # element. The sum of all slice values in the table should be 1.0,
    # unless unallocated space is desired.
    # Default: [ [ 1.0, '/data' ] ]
    attr_accessor :lvm_volumes

    # File System Type. Default: 'ext4'
    attr_accessor :fs_type

    # Array of FS specific options to pass as mkfs -t fs_type _OPTS_
    # Default: [] (none)
    attr_accessor :fs_opts

    # Mount options Array
    # Default: [ defaults auto noatime nodiratime ]
    attr_accessor :mount_opts

    def initialize( opts = {} )
      @instance = 0 #FIXME: Or compute from existing volumes?

      @raw_devices = []
      @raw_read_ahead = 32 #512B blocks
      @do_unmount = false

      @raid_level = nil #default_raid_level
      @raid_read_ahead  = 64  #512B blocks
      @raid_chunk       = 256 #K

      @lvm_volumes = [ [ 1.0, '/data' ] ]
      @fs_type = 'ext4'
      @fs_opts = []
      @mount_opts = %w[ defaults auto noatime nodiratime ]

      super
    end

    # Set raw devices to assemble.
    # * Interprets an Integer val as a count of N devices with names
    #   /dev/xvdh1 to /dev/xvdhN.
    # * Interprets a Range value as /dev/xvdhN for each N
    #   in range.
    # * Interprets  an Array as the actual device path strings.
    def raw_devices=( val )
      @raw_devices = case val
                     when Integer
                       val.times.map { |i| "/dev/xvdh#{i+1}" }
                     when Range
                       val.map { |i| "/dev/xvdh#{i}" }
                     when Array
                       val
                     else
                       raise "Unsupported raw_devices setting #{val.inspect}"
                     end
    end

    # Install only if _all_ lvm_volumes paths do not yet exist.
    def install
      return if raw_devices.empty? || lvm_volumes.empty?

      paths = lvm_volumes.map { |r| r[1] }
      test = paths.map { |p| "! -e #{p}" }.join( " -a " )

      sudo( "if [ #{test} ]; then", close: "fi" ) do

        dist_install( "mdadm", "lvm2", minimal: true )

        raw_devices.each do |d|
          unmount_device( d ) if do_unmount
          sudo "blockdev --setra #{raw_read_ahead} #{d}"
        end

        if raw_devices.count > 1
          dev = "/dev/md#{instance}"
          create_raid( dev )
        else
          dev = raw_devices.first
        end

        create_volumes( dev )

      end
    end

    private

    def create_raid( md )
      rlevel = raid_level || default_raid_level
      sudo <<-SH
        mdadm --create #{md} --level=#{rlevel} --chunk=#{raid_chunk} \
          --raid-devices=#{raw_devices.count} #{raw_devices.join ' '}
        touch /etc/mdadm.conf
        echo "DEVICE #{raw_devices.join ' '}" >> /etc/mdadm.conf
        mdadm --detail --scan >> /etc/mdadm.conf
        blockdev --setra #{raid_read_ahead} #{md}
      SH
    end

    def create_volumes( dev )
      vg = "vg#{instance}"
      sudo <<-SH
        dd if=/dev/zero of=#{dev} bs=512 count=1
        pvcreate #{dev}
        vgcreate #{vg} #{dev}
      SH

      lvm_volumes.each do |v|
        create_volume( *v )
      end
    end

    def create_volume( slice, path, name = nil )
      name ||= File.basename( path )
      vg = "vg#{instance}"
      sudo <<-SH
        lvcreate -l #{(slice * 100).round}%vg -n #{name} #{vg}
        mkfs -t #{fs_type} #{fs_opts.join ' '} /dev/#{vg}/#{name}
        mkdir -p #{path}
        echo '/dev/#{vg}/#{name} #{path} #{fs_type} #{mount_opts.join ','} 0 0' \
          >> /etc/fstab
        mount #{path}
      SH
    end

    def default_raid_level
      if raw_devices.count >= 4
        10
      else
        0
      end
    end

  end

end
