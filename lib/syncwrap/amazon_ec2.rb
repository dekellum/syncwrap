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

require 'time'
require 'securerandom'

require 'syncwrap/provider'

require 'syncwrap/amazon_ws'
require 'syncwrap/path_util'
require 'syncwrap/host'
require 'syncwrap/user_data'

module SyncWrap

  # Amazon EC2 host provider. Supports importing, creating, and
  # terminating hosts.
  #
  # == Synopsis
  #
  # Add the following to your sync.rb
  #
  #   ec2 = AmazonEC2.new( space )
  #
  # Then add profiles via #profile, as needed.
  #
  class AmazonEC2 < Provider
    include AmazonWS
    include PathUtil
    include UserData

    # FIXME: Interim strategy: use AmazonWS and defer deciding final
    # organization.

    protected

    # The json configuration file path, parsed and passed to
    # AWS::config. This file should contain a json object with the
    # minimal required keys: access_key_id, secret_access_key. A
    # relative path is interpreted relative to the :sync_file_path
    # option if provided on construction.  (default: private/aws.json)
    attr_accessor :aws_config

    public

    def initialize( space, opts = {} )
      @aws_config = 'private/aws.json'
      super

      # Look up aws_config (i.e. default private/aws.json) relative to
      # the sync file path.
      if @aws_config
        if sync_file_path
          @aws_config = File.expand_path( @aws_config, sync_file_path )
        end

        if File.exist?( @aws_config )
          aws_configure( @aws_config )
        else
          @aws_config = relativize( @aws_config )
          warn "WARNING: #{aws_config} not found. EC2 provider operations not available."
          @aws_config = nil
        end
      end
    end

    # FIXME: compare these for changes

    def import_hosts( regions, sync_file )
      require_configured!
      hlist = import_host_props( regions )
      unless hlist.empty?

        hlist.map! do |props|
          props[:name] ||= props[:id].to_s
          Host.new( space, props )
        end

        time = Time.now.utc
        cmt = "\n# Import of AWS #{regions.join ','} on #{time.iso8601}"
        append_host_definitions( hlist, sync_file, cmt )
      end
    end

    # Create new hosts and append host definitions to the sync_file.
    # If a block is given, each new host is yielded before appending.
    def create_hosts( count, profile, name, sync_file )
      require_configured!
      super
    end

    def create_host( profile, hname )
      aws_create_instance( hname, profile )
    end

    # Create a temporary host using the specified profile, yield to
    # block for provisioning, then create a machine image and
    # terminate the host. If block returns false, then the image will
    # not be created nor will the host be terminated.
    # On success, returns image_id (ami-*) and name.
    def create_image_from_profile( profile_key, sync_file )
      require_configured!
      profile = get_profile( profile_key ).dup
      tag = profile[ :tag ]
      profile[ :tag ] = tag = tag.call if tag.is_a?( Proc )

      opts = {}
      opts[ :name ] = profile_key.to_s
      opts[ :name ] += ( '-' + tag ) if tag
      opts[ :description ] = profile[ :description ]

      if image_name_exist?( profile[ :region ], opts[ :name ] )
        raise "Image name #{opts[:name]} (profile-tag) already exists."
      end

      hname = nil
      loop do
        hname = SecureRandom::hex(4)
        break unless space.get_host( hname )
      end
      create_hosts( 1, profile, hname, sync_file )
      host = space.host( hname, imaging: true )

      success = yield( host )

      if success
        image_id = create_image( host, opts )
        terminate_hosts( [ hname ], false, sync_file, false )
        [ image_id, opts[ :name ] ]
      end

    end

    def terminate_host( host, delete_attached_storage, do_wait = true )
      require_configured!
      raise "Host #{name} missing :id" unless host[:id]
      raise "Host #{name} missing :region" unless host[:region]
      aws_terminate_instance( host, delete_attached_storage, do_wait )
    end

    protected

    def require_configured!
      unless @aws_config
        raise( ":aws_config file not found, " +
               "operation not supported without AWS credentials" )
      end
    end

  end

end
