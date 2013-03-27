#--
# Copyright (c) 2011-2013 David Kellum
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

require 'json'
require 'aws-sdk'

require 'syncwrap/common'

# FIXME: rdoc
module SyncWrap::AWS
  include SyncWrap::Common

  # The json configuration file, parsed and passed directly to
  # AWS::config method. This file should contain a json object with
  # the minimal required keys: access_key_id, secret_access_key
  attr_accessor :aws_config_json

  attr_accessor :aws_instances_json

  # Array of region strings to check for aws_import_instances
  attr_accessor :aws_regions

  # Array of imported or read instances represented as hashes.
  attr_accessor :aws_instances

  # Default options (which may be overriden) in call to
  # aws_create_instance.
  attr_accessor :aws_default_instance_options

  def initialize
    @aws_config_json   = 'private/aws.json'
    @aws_regions       = %w[ us-east-1 ]
    @aws_instances_json = 'aws_instances.json'
    @aws_instances = []
    @aws_default_instance_options = {
      :ebs_volumes     => 0,
      :ebs_volume_options => { :size => 16 }, #gb
      :lvm_volumes     => [ [ 1.00, '/data' ] ],
      :security_groups => :default,
      :instance_type   => 'm1.medium',
      :region          => 'us-east-1'
    }

    super

    aws_configure
    aws_read_instances if File.exist?( @aws_instances_json )
  end

  def aws_configure
    AWS.config( JSON.parse( IO.read( @aws_config_json ),
                            :symbolize_names => true ) )
  end

  # Create an instance, using name as the Name tag and assumed
  # localhost name. For options see
  # {AWS::EC2::InstanceCollection.create}[http://docs.aws.amazon.com/AWSRubySDK/latest/AWS/EC2/InstanceCollection.html#create-instance_method]
  # with the following additions/differences:
  #
  # :count:: must be 1 or unspecified.
  # :region:: Default 'us-east-1'
  # :security_groups:: As per aws-sdk, but the special :default value
  #                    is replaced with a single security group with
  #                    same name as the :region option.
  # :ebs_volumes:: The number of EBS volumes to create an attach to this instance.
  # :ebs_volume_options:: A nested Hash of options, as per
  #                       {AWS::EC2::VolumeCollection.create}[http://docs.aws.amazon.com/AWSRubySDK/latest/AWS/EC2/VolumeCollection.html#create-instance_method]
  #                       with custom default :size 16 GB, and the same
  #                       :availibility_zone as the instance.
  # :lvm_volumes:: Ignored here.
  def aws_create_instance( name, opts = {} )
    opts = deep_merge_hashes( @aws_default_instance_options, opts )
    region = opts.delete( :region )
    opts.delete( :lvm_volumes ) #unused here

    ec2 = AWS::EC2.new.regions[ region ]

    if opts[ :count ] && opts[ :count ] != 1
      raise ":count #{opts[ :count ]} != 1 is not supported"
    end

    if opts[ :security_groups ] == :default
      opts[ :security_groups ] = [ opts[ :region ] ]
    end

    inst = ec2.instances.create( opts )

    inst.add_tag( 'Name', :value => name )

    if opts[ :roles ]
      inst.add_tag( 'Roles', :value => opts[ :roles ].join(' ') )
    end

    wait_for_running( inst )

    if opts[ :ebs_volumes ] > 0
      vopts = { :availability_zone => inst.availability_zone }.
        merge( opts[ :ebs_volume_options ] )

      attachments = opts[ :ebs_volumes ].times.map do |i|
        vol = ec2.volumes.create( vopts )
        vol.attach_to( inst, "/dev/sdh#{i+1}" ) #=> Attachment
      end

      sleep 1 while attachments.any? { |a| a.status == :attaching }
    end

    aws_instance_added( aws_instance_to_props( region, inst ) )
    aws_write_instances
  end

  def aws_instance_added( inst )
    @aws_instances << inst
    @aws_instances.sort! { |p,n| p[:name] <=> n[:name] }
  end

  def wait_for_running( inst )
    while ( stat = inst.status ) == :pending
      puts "Waiting 1s for instance to run"
      sleep 1
    end
    unless stat == :running
      raise "Instance #{inst.id} has status #{stat}"
    end
    nil
  end

  # Find running/pending instances in each of aws_regions, convert to
  # props, and save in aws_instances list.
  def aws_import_instances

    instances = []

    aws_regions.each do |region|
      ec2 = AWS::EC2.new.regions[ region ]

      found = ec2.instances.map do |inst|
        next unless [ :running, :pending ].include?( inst.status )
        aws_instance_to_props( region, inst )
      end

      instances += found.compact
    end

    @aws_instances = instances
  end

  def aws_instance_to_props( region, inst )
    tags = inst.tags.to_h
    name = tags[ 'Name' ]
    roles = decode_roles( tags[ 'Roles' ] )

    { :id     => inst.id,
      :region => region,
      :ami    => inst.image_id,
      :name   => name,
      :internet_name => inst.dns_name,
      :internet_ip   => inst.ip_address,
      :internal_ip   => inst.private_ip_address,
      :instance_type => inst.instance_type,
      :roles  => roles }
  end

  # Read the aws_instances_json file, replacing in RAM AWS instances
  def aws_read_instances
    list = JSON.parse( IO.read( aws_instances_json ), :symbolize_names => true )
    list.each do |inst|
      inst[:roles] = ( inst[:roles] || [] ).map { |r| r.to_sym }
    end
    @aws_instances = list.sort { |p,n| p[:name] <=> n[:name] }
  end

  # Overwrite aws_instances_json file with the current AWS instances.
  def aws_write_instances
    File.open( aws_instances_json, 'w' ) do |fout|
      aws_dump_instances( fout )
    end
  end

  # Dump AWS instances as JSON but with custom layout of host per line.
  def aws_dump_instances( fout = $stdout )
    fout.puts '['
    rows = @aws_instances.sort { |p,n| p[:name] <=> n[:name] }
    rows.each_with_index do |row, i|
      fout.puts( "  " + JSON.generate( row, :space => ' ', :object_nl => ' ' ) +
                 ( ( i == ( rows.length - 1 ) ) ? '' : ',' ) )
    end
    fout.puts ']'
  end

  def decode_roles( roles )
    ( roles || "" ).split( /\s+/ ).map { |r| r.to_sym }
  end

  # Runs create_lvm_volumes! if the first :lvm_volumes mount path does
  # not yet exist.
  def create_lvm_volumes( opts = {} )
    opts = deep_merge_hashes( @aws_default_instance_options, opts )
    unless exist?( opts[ :lvm_volumes ].first[1] )
      create_lvm_volumes!( opts )
    end
  end

  # Create an mdraid array from previously attached EBS volumes, then
  # divvy up across N lvm mount points by ratio, creating filesystems and
  # mounting.  This mdadm and lvm recipe was originally derived from
  # {Install MongoDB on Amazon EC2}[http://docs.mongodb.org/ecosystem/tutorial/install-mongodb-on-amazon-ec2/]
  #
  # === Options
  # :ebs_volumes:: The number of EBS volumes previously created and
  #                attached to this instance.
  # :lvm_volumes:: A table of [ slice, path (,name) ] rows where;
  #                slice is a floating point ratio in range (0.0,1.0],
  #                path is the mount point, and name is the lvm name,
  #                defaulting if omitted to the last path element. The
  #                sum of all slice values in the table should be 1.0.
  def create_lvm_volumes!( opts = {} )
    opts = deep_merge_hashes( @aws_default_instance_options, opts )

    vol_count = opts[ :ebs_volumes ]
    devices = vol_count.times.map { |i| "/dev/xvdh#{i+1}" }

    cmd = <<-SH
      #{dist_install_s( "mdadm", "lvm2", :minimal => true )}
      mdadm --create /dev/md0 --level=10 --chunk=256 --raid-devices=#{vol_count} \
        #{devices.join ' '}
      echo "DEVICE #{devices.join ' '}" > /etc/mdadm.conf
      mdadm --detail --scan >> /etc/mdadm.conf
    SH

    devices.each do |d|
      cmd << <<-SH
        blockdev --setra 128 #{d}
      SH
    end

    cmd << <<-SH
      blockdev --setra 128 /dev/md0
      dd if=/dev/zero of=/dev/md0 bs=512 count=1
      pvcreate /dev/md0
      vgcreate vg0 /dev/md0
    SH

    opts[ :lvm_volumes ].each do | slice, path, name |
      name ||= ( path =~ /\/(\w+)$/ ) && $1
      cmd << <<-SH
        lvcreate -l #{(slice * 100).round}%vg -n #{name} vg0
        mke2fs -t ext4 -F /dev/vg0/#{name}
        if [ -d #{path} ]; then
          rm -rf #{path}
        fi
        mkdir -p #{path}
        echo '/dev/vg0/#{name} #{path} ext4 defaults,auto,noatime,noexec 0 0' >> /etc/fstab
        mount #{path}
      SH
    end

    sudo cmd
  end

end
