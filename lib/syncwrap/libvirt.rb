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

require 'securerandom'
require 'rexml/document'

require 'syncwrap/provider'
require 'syncwrap/host'

module SyncWrap

  # Supports creating and terminating hosts using libvirt, QEMU (KVM)
  class Libvirt < Provider

    # The Hypervisor URI to use for provisioning hosts
    # (Default: qemu:///system)
    attr_reader   :virt_uri

    # If true, use sudo for all `virsh` and qemu/image file
    # interactions. Setting this to false requires non-default group
    # and permissions configuration in libvirt.
    # (Default: true)
    attr_reader   :sudo

    def initialize( *args )
      super
      @virt_uri = 'qemu:///system'
      @sudo = true
    end

    def create_host( profile, name )
      props = profile.dup
      props[ :name ] = name
      props[ :uuid ] ||= SecureRandom.uuid
      props[ :mac_address ] ||= random_mac

      dom = parse_domain( props[ :image_name ] )
      Dir.mktmpdir( 'syncwrap-libvirt-' ) do |dir|
        dfile = File.join( dir, 'domain.xml' )
        File.open( dfile, "w" ) do |fout|
          fout.puts( permute_domain( dom, props ) )
        end
        create_domain( dfile, props )
      end

      ip = local_ip_lookup( props[ :mac_address ], name )
      props[:internal_ip] = ip
      props[:internet_ip] = ip

      props
    end

    def terminate_host( host, delete_attached_storage, do_wait = true )
      system!( virsh_args( 'destroy', host[:name] ) )

      loop do
        lines = popen!( virsh_args( 'list', '--name' ) ) do |io|
          io.readlines
        end
        names = lines.map(&:chomp)
        break( true ) unless names.include?( host[:name ] )
        sleep 0.2
        #FIXME: Timeout? output...?
      end

      host[:disk].values.each do |disk|
        if disk[:file] && disk[:delete_on_terminate] || delete_attached_storage
          system!( sudo_args( 'rm', '-f', disk[:file] ) )
          puts "Deleted #{disk[:file]}"
        end
      end

      system!( [ 'ssh-keygen', '-R', host[:internal_ip] ] )
    end

    private

    def random_mac
      # https://github.com/rlaager/python-virtinst/blob/master/virtinst/util.py#L181
      # QEMU/KVM allocated mac prefix
      3.times.inject( %w[ 52 54 00 ] ) do |m,_|
        m << SecureRandom.hex(1)
      end.join( ':' )
    end

    def parse_domain( name )
      dump = popen!( virsh_args( 'dumpxml', name ) ) do |io|
        io.read
      end
      REXML::Document.new( dump )
    end

    def permute_domain( dom, props )
      dom = dom.dup

      dom.elements[ 'domain/name' ].text = props[ :name ]
      dom.elements[ 'domain/uuid' ].text = props[ :uuid ]

      disk = dom.elements[ "domain/devices/disk[@device='disk']" ]
      permute_root_disk( disk, props )

      net = dom.elements[ "domain/devices/interface[@type='network']" ]
      net.elements['mac'].attributes['address'] = props[ :mac_address ]

      dom
    end

    def permute_root_disk( disk, props )
      if disk.attributes['type'] == 'file'
        src = disk.elements['source']
        old_file = src.attributes['file']
        rprops = props[ :disk ] && props[ :disk ][ :root ]
        file = rprops && rprops[ :file ]
        file ||= old_file.sub( /(\.\w+)?$/, "-#{props[:name]}\\1" )
        props[ :disk ] ||= {}
        props[ :disk ][ :root ] ||= {}
        props[ :disk ][ :root ][ :file ] = file
        if !File.exist?( file )
          type = disk.elements['driver'].attributes['type']
          qemu_image( old_file, file, type, props )
        end

        src.attributes['file'] = file
        disk.delete_element( 'readonly' )
      end
    end

    def qemu_image( old_file, new_file, type, props )
      args = []
      args << 'qemu-img' << 'create' << '-f' << type
      args << '-b' << old_file if type == 'qcow2'
      args << new_file
      system!( sudo_args( *args ) )
    end

    def create_domain( dfile, props )
      system!( virsh_args( 'create', dfile ) )
    end

    def local_ip_lookup( mac, name )
      loop do
        lines = popen!( virsh_args( 'domifaddr', name ) ) do |io|
          io.readlines
        end
        lines.each do |line|
          if line =~ /#{mac}\s+ipv4\s+([0-9][0-9.]+)/
            return $1
          end
        end
        sleep 0.2
        #FIXME: Timeout? output...?
      end
      nil
    end

    def sudo_args( *sargs )
      args = []
      args << 'sudo' if sudo
      args + sargs
    end

    def virsh_args( *vargs )
      args = []
      args << 'virsh'
      args << '-c' << virt_uri if virt_uri
      args += vargs
      sudo_args( *args )
    end

    def system!( args )
      system( *args ) or raise "#{args.join ' '} failed with #{$?}"
    end

    def popen!( args, &block )
      ret = IO.popen( args, &block )
      raise "#{args.join ' '} failed with #{$?}" unless $?.exitstatus == 0
      ret
    end

  end

end
