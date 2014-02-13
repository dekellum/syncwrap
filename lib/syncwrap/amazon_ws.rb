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

require 'aws-sdk'
require 'resolv'
require 'json'

module SyncWrap

  # Supports host provisioning in EC2 via AWS APIs, creating and
  # attaching EBS volumes, and creating Route53 record sets.
  module AmazonWS

    # Default options for Route53 record set creation
    attr_accessor :route53_default_rs_options

    # DNS Resolver options for testing Route53 (default: Use public
    # google name servers to avoid local negative caching)
    attr_accessor :resolver_options

    def initialize
      @default_instance_options = {
        ebs_volumes:        0,
        ebs_volume_options: { size: 16 }, #gb
        lvm_volumes:        [ [ 1.00, '/data' ] ],
        security_groups:    [ :default ],
        instance_type:      'm1.medium',
        region:             'us-east-1'
      }
      @route53_default_rs_options = {
        ttl:  300,
        wait: true
      }

      @resolver_options = {
        nameserver: [ '8.8.8.8', '8.8.4.4' ]
      }

      super
    end

    protected

    def aws_configure( json_file )
      AWS.config( JSON.parse( IO.read( json_file ),
                              symbolize_names: true ) )
    end

    # Create a security_group given name and options. :region is the
    # only required option, :description is good to have. Currently
    # this is a no-op if the security group already exists.
    def aws_create_security_group( name, opts = {} )
      opts = opts.dup
      region = opts.delete( :region )
      ec2 = AWS::EC2.new.regions[ region ]
      unless ec2.security_groups.find { |sg| sg.name == name }
        sg = ec2.security_groups.create( name, opts )

        # FIXME: Allow ssh on the "default" region named group
        if name == region
          sg.authorize_ingress(:tcp, 22)
        end
      end
    end

    # Create an instance, using name as the Name tag and assumed
    # host name. For options see
    # {AWS::EC2::InstanceCollection.create}[http://docs.aws.amazon.com/AWSRubySDK/latest/AWS/EC2/InstanceCollection.html#create-instance_method]
    # with the following additions/differences:
    #
    # :count:: must be 1 or unspecified.
    # :region:: Default 'us-east-1'
    # :security_groups:: As per aws-sdk, but the special :default value
    #                    is replaced with a single security group with
    #                    same name as the :region.
    # :ebs_volumes:: The number of EBS volumes to create an attach to this instance.
    # :ebs_volume_options:: A nested Hash of options, as per
    #                       {AWS::EC2::VolumeCollection.create}[http://docs.aws.amazon.com/AWSRubySDK/latest/AWS/EC2/VolumeCollection.html#create-instance_method]
    #                       with custom default :size 16 GB, and the same
    #                       :availibility_zone as the instance.
    # :lvm_volumes:: Ignored here.
    # :roles:: Array of role Strings or Symbols (applied as Roles tag)
    def aws_create_instance( name, opts = {} )
      opts = deep_merge_hashes( @default_instance_options, opts )
      region = opts.delete( :region )
      opts.delete( :lvm_volumes ) #unused here

      ec2 = AWS::EC2.new.regions[ region ]

      iopts = opts.dup
      iopts.delete( :ebs_volumes )
      iopts.delete( :ebs_volume_options )
      iopts.delete( :roles )

      if iopts[ :count ] && iopts[ :count ] != 1
        raise ":count #{iopts[ :count ]} != 1 is not supported"
      end

      iopts[ :security_groups ].map! do |sg|
        sg == :default ? region : sg
      end

      iopts[ :security_groups ].each do |sg|
        aws_create_security_group( sg, region: region )
      end

      inst = ec2.instances.create( iopts )

      inst.add_tag( 'Name', value: name )

      if opts[ :roles ]
        inst.add_tag( 'Roles', value: opts[ :roles ].join(' ') )
      end

      wait_for_running( inst )

      # FIXME: Split method
      # FIXME: Support alternative syntax, i.e
      # { ebs_volumes: [ [4, size: 48], [2, size: 8] ] }

      if opts[ :ebs_volumes ] > 0
        vopts = { availability_zone: inst.availability_zone }.
          merge( opts[ :ebs_volume_options ] )

        attachments = opts[ :ebs_volumes ].times.map do |i|
          vol = ec2.volumes.create( vopts )
          wait_until( vol.id, 0.5 ) { vol.status == :available }
          vol.attach_to( inst, "/dev/sdh#{i+1}" ) #=> Attachment
        end

        wait_until( "volumes to attach" ) do
          !( attachments.any? { |a| a.status == :attaching } )
        end
      end
      #FIXME: end

      instance_to_props( region, inst )
    end

    # Create a Route53 DNS CNAME from iprops :name to :internet_name.
    # Options are per {AWS::Route53::ResourceRecordSetCollection.create}[http://docs.aws.amazon.com/AWSRubySDK/latest/AWS/Route53/ResourceRecordSetCollection.html#create-instance_method]
    # (currently undocumented) with the following additions:
    #
    # :domain_name:: name of the hosted zone and suffix for
    #                CNAME. Should terminate in a DOT '.'
    # :wait::        If true, wait for CNAME to resolve
    def route53_create_host_cname( iprops, opts = {} )
      opts = deep_merge_hashes( @route53_default_rs_options, opts )
      dname = dot_terminate( opts.delete( :domain_name ) )
      do_wait = opts.delete( :wait )
      rs_opts = opts.
        merge( resource_records: [ {value: iprops[:internet_name]} ] )

      r53 = AWS::Route53.new
      zone = r53.hosted_zones.find { |hz| hz.name == dname } or
        raise "Route53 Hosted Zone name #{dname} not found"
      long_name = [ iprops[:name], dname ].join('.')
      zone.rrsets.create( long_name, 'CNAME', rs_opts )
      wait_for_dns_resolve( long_name, dname ) if do_wait
    end

    def wait_for_dns_resolve( long_name,
                              domain,
                              rtype = Resolv::DNS::Resource::IN::CNAME )

      ns_addr = Resolv::DNS.open( @resolver_options ) do |rvr|
        ns_n = rvr.getresource( domain, Resolv::DNS::Resource::IN::SOA ).mname
        rvr.getaddress( ns_n ).to_s
      end

      sleep 3 # Initial wait

      wait_until( "#{long_name} to resolve", 3.0 ) do
        Resolv::DNS.open( nameserver: ns_addr ) do |rvr|
          rvr.getresources( long_name, rtype ).first
        end
      end
    end

    # Terminate an instance and wait for it to be terminated. If
    # requested, /dev/sdh# attached EBS volumes which are not
    # otherwise marked for :delete_on_termination will _also_ be
    # terminated.  The minimum required properties in iprops are
    # :region and :id.
    #
    # _WARNING_: data _will_ be lost!
    def aws_terminate_instance( iprops, delete_attached_storage = false )
      ec2 = AWS::EC2.new.regions[ iprops[ :region ] ]
      inst = ec2.instances[ iprops[ :id ] ]
      unless inst.exists?
        raise "Instance #{iprops[:id]} does not exist in #{iprops[:region]}"
      end

      ebs_volumes = []
      if delete_attached_storage
        ebs_volumes = inst.block_devices.map do |dev|
          ebs = dev[ :ebs ]
          if ebs && dev[:device_name] =~ /dh\d+$/ && !ebs[:delete_on_termination]
            ebs[ :volume_id ]
          end
        end.compact
      end

      inst.terminate
      wait_until( "termination of #{inst.id}", 2.0 ) { inst.status == :terminated }

      ebs_volumes = ebs_volumes.map do |vid|
        volume = ec2.volumes[ vid ]
        if volume.exists?
          volume
        else
          puts "WARN: #{volume} doesn't exist"
          nil
        end
      end.compact

      ebs_volumes.each do |vol|
        wait_until( "deletion of vol #{vol.id}" ) do
          vol.status == :available || vol.status == :deleted
        end
        vol.delete if vol.status == :available
      end

    end

    def wait_for_running( inst )
      wait_until( "instance #{inst.id} to run", 2.0 ) { inst.status != :pending }
      stat = inst.status
      raise "Instance #{inst.id} has status #{stat}" unless stat == :running
      nil
    end

    # Find running or pending instances in each region String and
    # convert to a HostList.
    def import_host_props( regions )
      regions.inject([]) do |insts, region|
        ec2 = AWS::EC2.new.regions[ region ]

        found = ec2.instances.map do |inst|
          next unless [ :running, :pending ].include?( inst.status )
          instance_to_props( region, inst )
        end

        insts + found.compact
      end

    end

    def instance_to_props( region, inst )
      tags = inst.tags.to_h

      { id:      inst.id,
        region:  region,
        ami:     inst.image_id,
        name:    tags[ 'Name' ],
        internet_name:  inst.dns_name,
        internet_ip:    inst.ip_address,
        internal_ip:    inst.private_ip_address,
        instance_type:  inst.instance_type,
        roles:   decode_roles( tags[ 'Roles' ] ) }
    end

    def decode_roles( roles )
      ( roles || "" ).split( /\s+/ ).map { |r| r.to_sym }
    end

    # Wait until block returns truthy, sleeping for freq seconds
    # between attempts. Writes desc and a sequence of DOTs on a single
    # line until complete.
    def wait_until( desc, freq = 1.0 )
      $stdout.write( "Waiting for " + desc )
      until (ret = yield) do
        $stdout.write '.'
        sleep freq
      end
      ret
    ensure
      puts
    end

    def dot_terminate( name )
      ( name =~ /\.$/ ) ? name : ( name + '.' )
    end

    def deep_merge_hashes( h1, h2 )
      h1.merge( h2 ) do |key, v1, v2|
        if v1.is_a?( Hash ) && v2.is_a?( Hash )
          deep_merge_hashes( v1, v2 )
        else
          v2
        end
      end
    end
  end
end