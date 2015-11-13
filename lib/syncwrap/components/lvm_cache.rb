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

require 'syncwrap/component'

module SyncWrap

  # Provision a cache using a fast drive (like an SSD) over a
  # slow drive (magnetic or network attached) via LVM's cache-pool
  # mechanism and dm-cache.
  #
  # Host component dependencies: <Distro>
  class LVMCache < Component

    protected

    # The target size of the cache metadata volume as a string. The
    # dm-cache guidelines are 1/1000th of the cache volume size and a
    # minimum of 8M (MiB). Default: '8M'
    attr_accessor :meta_size

    # The target size of the cache volume as a string. This may either
    # express a percentage (via -l) or a real size (via -L, ex: '30G')
    # Default: '100%FREE'
    attr_accessor :cache_size

    # A volume group instance number compatible with the naming used
    # by MDRaid. The cache and cache-meta volumes must all be under
    # the same volume group as the lv_cache_target volume.
    # Default: 0 -> 'vg0'
    attr_accessor :vg_instance

    # The fast raw device to use as the cache, i.e. '/dev/xvdb'
    # (required)
    attr_accessor :raw_device

    # The target volume name in the same volume group to
    # cache. (required)
    attr_accessor :lv_cache_target

    # The name of the cache volume
    # Default: lv_cache_target + '_cache'
    attr_writer :lv_cache

    # Array of additional flags to vgextend
    # Default: ['-y']
    attr_accessor :vgextend_flags

    def lv_cache
      @lv_cache || ( lv_cache_target + '_cache' )
    end

    def lv_cache_meta
      lv_cache + '_meta'
    end

    def vg
      "vg#{vg_instance}"
    end

    public

    def initialize( opts = {} )
      @meta_size = '8M'
      @cache_size = '100%FREE'
      @vg_instance = 0
      @raw_device = nil
      @lv_cache_target = nil
      @lv_cache = nil
      @vgextend_flags = %w[ -y ]
      super

      raise "LVMCache#raw_device not set" unless raw_device
      raise "LVMCache#lv_cache_target not set" unless lv_cache_target
    end

    def install
      dist_install( "lvm2", minimal: true )
      sudo( "if ! lvs /dev/#{vg}/#{lv_cache}; then", close: "fi" ) do
        unmount_device( raw_device )
        sudo <<-SH
          vgextend #{vgextend_flags.join ' '} #{vg} #{raw_device}
          lvcreate -L #{meta_size} -n #{lv_cache_meta} #{vg} #{raw_device}
          lvcreate #{cache_size_flag} -n #{lv_cache} #{vg} #{raw_device}
          lvconvert --type cache-pool --cachemode writethrough --yes \
                    --poolmetadata #{vg}/#{lv_cache_meta} #{vg}/#{lv_cache}
          lvconvert --type cache --cachepool #{vg}/#{lv_cache} #{vg}/#{lv_cache_target}
        SH
      end
    end

    protected

    def cache_size_flag
      if cache_size =~ /%/
        "-l #{cache_size}"
      else
        "-L #{cache_size}"
      end
    end
  end

end
