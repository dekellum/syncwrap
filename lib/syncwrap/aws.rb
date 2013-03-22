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

require 'syncwrap/base'

# FIXME: rdoc
module SyncWrap::AWS

  # The json configuration file, parsed and passed directly to
  # AWS::config method. This file should contain a json object with
  # the minimal required keys: access_key_id, secret_access_key
  attr_accessor :aws_config_json

  attr_accessor :aws_regions

  def initialize
    @aws_config_json = './private/aws.json'
    @aws_regions = %w[ us-east-1 ]
    super

    aws_configure
  end

  def aws_configure
    AWS.config( JSON.parse( IO.read( @aws_config_json ),
                            :symbolize_names => true ) )
  end

  def aws_dump_instances( fout = $stdout )
    fout.puts '['

    aws_regions.each do |region|
      ec2 = AWS::EC2.new.regions[ region ]

      rows = ec2.instances.map do |inst|
        next unless [ :running, :pending ].include?( inst.status )

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

      rows = rows.compact.sort { |p,n| p[:name] <=> n[:name] }
      rows.each_with_index do |row, i|
        fout.puts( "  " + JSON.generate( row, :space => ' ', :object_nl => ' ' ) +
                   ( ( i == ( rows.length - 1 ) ) ? '' : ',' ) )
      end
    end

    fout.puts ']'

  end

  def decode_roles( roles )
    ( roles || "" ).split( /\s+/ ).map { |r| r.to_sym }
  end

end

if $0 == __FILE__
  class Test
    include SyncWrap::AWS
  end

  t = Test.new
  t.aws_dump_instances
end
