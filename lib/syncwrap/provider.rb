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

require 'syncwrap/base'

module SyncWrap

  # A provider base class with generic profile and sync file
  # edit support.
  class Provider

    attr_accessor :sync_file_path

    def initialize( space, opts = {} )
      @space = space
      @profiles = {}
      @sync_file_path = nil
      super()
      opts.each do |name,val|
        send( name.to_s + '=', val )
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

    # Create new hosts and append host definitions to the sync_file.
    # If a block is given, each new host is yielded before appending.
    def create_hosts( count, profile, name, sync_file )
      profile = get_profile( profile ) if profile.is_a?( Symbol )
      profile = profile.dup
      dname = profile.delete( :default_name )
      name ||= dname

      count.times do
        hname = if count == 1
                  raise "Host #{name} already exists!" if space.get_host( name )
                  name
                else
                  find_name( name )
                end
        props = create_host( profile, hname )
        host = space.host( props )
        yield( host ) if block_given?
        append_host_definitions( [ host ], sync_file )
        host[ :just_created ] = true
      end
    end

    def terminate_hosts( names, delete_attached_storage, sync_file, do_wait = true )
      names.each do |name|
        host = space.get_host( name )
        raise "Host #{name} not found in Space, sync file." unless host
        terminate_host( host, delete_attached_storage, do_wait )
        delete_host_definition( host, sync_file )
      end
    end

    def import_hosts( regions, sync_file )
      raise "#{self.class.name}#import_hosts not implemented"
    end

    def create_image_from_profile( profile_key, sync_file )
      raise "#{self.class.name}#create_image_from_profile not implemented"
    end

    protected

    attr_reader :space

    def append_host_definitions( hosts, sync_file, comment = nil )
      File.open( sync_file, "a" ) do |out|
        out.puts comment if comment

        hosts.each do |host|
          props = host.props.dup
          props.delete( :name )

          roles = ( host.roles - [:all] ).map { |s| ':' + s.to_s }.join ', '
          roles << ',' unless roles.empty?
          props = host.props.map do |key,val|
            "#{key}: #{serialize_value( val )}" unless key == :name
          end.compact.join ",\n      "

          out.puts "host( '#{host.name}', #{roles}"
          out.puts "      #{props} ) # :auto-generated"
        end
      end
    end

    def serialize_value( val )
      case val
      when Hash
        ( '{' +
          val.map { |k,v| k.to_s + ': ' + serialize_value( v ) }.join(', ') +
          '}' )
      else
        val.inspect
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

  end

end
