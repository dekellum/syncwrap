#--
# Copyright (c) 2011-2018 David Kellum
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
  class AmazonEC2
    include AmazonWS
    include PathUtil
    include UserData

    # FIXME: Interim strategy: use AmazonWS and defer deciding final
    # organization.

    # The json configuration file path, parsed and passed to
    # AWS::config. This file should contain a json object with the
    # minimal required keys: access_key_id, secret_access_key. A
    # relative path is interpreted relative to the :sync_file_path
    # option if provided on construction.  (default: private/aws.json)
    attr_accessor :aws_config

    def initialize( space, opts = {} )
      super()
      @profiles = {}
      @space = space
      @aws_config = 'private/aws.json'
      opts = opts.dup
      sync_file_path = opts.delete( :sync_file_path )
      opts.each { |name, val| send( name.to_s + '=', val ) }

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

    # Define a host profile by Symbol key and Hash value.
    #
    # Profiles may inherit properties from a :base_profile, either
    # specified by that key, or the :default profile. The
    # base_profile must be defined in advance (above in the sync
    # file). When merging profile to any base_profile, the :roles
    # property is concatenated via set union. All other properties are
    # overwritten.
    #
    # FIXME: All other profile properties are as currently defined by
    # #aws_create_instance.
    def profile( key, profile )
      profile = profile.dup
      base = profile.delete( :base_profile ) || :default
      base_profile = @profiles[ base ]
      if base_profile
        profile = base_profile.merge( profile )
        if base_profile[ :roles ] && profile[ :roles ]
          profile[ :roles ] = ( base_profile[ :roles ] | profile[ :roles ] )
        end
      end

      @profiles[ key ] = profile
    end

    def get_profile( key )
      @profiles[ key ] or raise "Profile #{key} not registered"
    end

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
        append_host_definitions( hlist, cmt, sync_file )
      end
    end

    # Create new hosts and append host definitions to the sync_file.
    # If a block is given, each new host is yielded before appending.
    def create_hosts( count, profile, name, sync_file )
      require_configured!
      profile = get_profile( profile ) if profile.is_a?( Symbol )
      profile = profile.dup

      # FIXME: Support profile overrides? Also add some targeted CLI
      # overrides (like for :availability_zone)?

      if profile[ :user_data ] == :ec2_user_sudo
        profile[ :user_data ] = no_tty_sudoer( 'ec2-user' )
      end

      dname = profile.delete( :default_name )
      name ||= dname

      count.times do
        hname = if count == 1
                  raise "Host #{name} already exists!" if space.get_host( name )
                  name
                else
                  find_name( name )
                end
        props = aws_create_instance( hname, profile )
        host = space.host( props )
        yield( host ) if block_given?
        append_host_definitions( [ host ], nil, sync_file )
        host[ :just_created ] = true
        # Need to use a host prop for this since context(s) do not
        # exist yet. Note it is set after append_host_definitions, to
        # avoid permanently writing this property to the sync_file.
      end
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

    def terminate_hosts( names, delete_attached_storage, sync_file, do_wait = true )
      require_configured!
      names.each do |name|
        host = space.get_host( name )
        raise "Host #{name} not found in Space, sync file." unless host
        raise "Host #{name} missing :id" unless host[:id]
        raise "Host #{name} missing :region" unless host[:region]
        aws_terminate_instance( host, delete_attached_storage, do_wait )
        delete_host_definition( host, sync_file )
      end
    end

    private

    attr_reader :space

    def require_configured!
      unless @aws_config
        raise( ":aws_config file not found, " +
               "operation not supported without AWS credentials" )
      end
    end

    def find_name( prefix )
      i = 1
      name = nil
      loop do
        name = "%s-%2d" % [ prefix, i ]
        break if !space.get_host( name )
        i += 1
      end
      name
    end

    def append_host_definitions( hosts, comment, sync_file )
      File.open( sync_file, "a" ) do |out|
        out.puts comment if comment

        hosts.each do |host|
          props = host.props.dup
          props.delete( :name )

          roles = ( host.roles - [:all] ).map { |s| ':' + s.to_s }.join ', '
          roles << ',' unless roles.empty?
          props = host.props.map do |key,val|
            "#{key}: #{val.inspect}" unless key == :name
          end.compact.join ",\n      "

          out.puts "host( '#{host.name}', #{roles}"
          out.puts "      #{props} ) # :auto-generated"
        end
      end
    end

    def delete_host_definition( host, sync_file )
      lines = IO.readlines( sync_file )
      out_lines = []
      state = :find
      lines.each do |line|
        if state == :find
          if line =~ /^host\( '#{host.name}',/
            state = :just_found
          else
            out_lines << line
          end
        end
        if state == :just_found || state == :found
          if state == :found && line =~ /^host\(/
            state = :no_end
            break
          end
          state = :found
          if line =~ /^\s*[^#].*\) # :auto-generated$/
            state = :deleted
          end
        elsif state == :deleted
          out_lines << line
        end
      end

      if state == :deleted
        File.open( sync_file, "w" ) do |out|
          out.puts out_lines
        end
      else
        $stderr.puts( "WARNING: #{sync_file} entry not deleted (#{state})" )
      end
    end

  end

end
