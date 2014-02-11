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

require 'time'

require 'syncwrap/amazon_aws'
require 'syncwrap/host'

module SyncWrap

  #
  # == Synopsis
  # Add the following to your sync.rb
  #
  #   ec2 = AmazonEC2.new( space )
  #
  class AmazonEC2
    include AmazonAWS

    # FIXME: Interim strategy: use AmazonAWS and defer deciding final
    # organization.

    attr_reader :space

    def initialize( space, opts = {} )
      super()
      @profiles = {}
      @space = space
      opts.each { |name, val| send( name.to_s + '=', val ) }
      @space.provider = self
    end

    def profile( key, profile )
      @profiles[ key ] = profile
    end

    def import_hosts( regions, output_file )
      hlist = import_host_props( regions )
      unless hlist.empty?

        hlist.map! do |props|
          props[:name] ||= props[:id].to_s
          Host.new( space, props )
        end

        time = Time.now.utc
        cmt = "\n# Import of AWS #{regions.join ','} on #{time.iso8601}"
        append_host_definitions( hlist, cmt, output_file )
      end
    end

    def create_hosts( count, profile_key, name, output_file )
      profile = @profiles[ profile_key ].dup or
        raise "Profile #{profile_key} not registered"

      if profile[ :user_data ] == :ec2_user_sudo
        profile[ :user_data ] = ec2_user_data
      end

      dname = profile.delete( :default_name )
      name ||= dname

      count.times do
        hname = if count == 1
                  if space.host_names.include?( name )
                    raise "Host #{name} already exists!"
                  end
                  name
                else
                  find_name( name )
                end
        props = aws_create_instance( hname, profile )
        host = space.host( props )
        append_host_definitions( [ host ], nil, output_file )
      end
    end

    def terminate_hosts( names, sync_file )
      names.each do |name|
        if space.host_names.include?( name )
          host = space.host( name )
          raise "Host #{name} missing :id" unless host[:id]
          raise "Host #{name} missing :region" unless host[:region]
          aws_terminate_instance_and_ebs_volumes( host )
          delete_host_definition( host, sync_file )
        else
          raise "Host #{name} not found in Space, sync file."
        end
      end
    end

    def find_name( prefix )
      host_names = space.host_names
      i = 1
      name = nil
      loop do
        name = "%s-%2d" % [ prefix, i ]
        break if ! host_names.include?( name )
        i += 1
      end
      name
    end

    def append_host_definitions( hosts, comment, output_file )
      File.open( output_file, "a" ) do |out|
        out.puts comment if comment

        hosts.each do |host|
          props = host.props.dup
          props.delete( :name )

          roles = host.roles.map { |s| ':' + s.to_s }.join ', '
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

    def ec2_user_data( user = 'ec2-user' )
      #FIXME: Utility module for this (+ Users sudoers)?
      script = <<-SH
        #!/bin/sh -e
        echo '#{user} ALL=(ALL) NOPASSWD:ALL'  > /etc/sudoers.d/#{user}
        echo 'Defaults:#{user} !requiretty'   >> /etc/sudoers.d/#{user}
        chmod 440 /etc/sudoers.d/#{user}
      SH
      script.split( "\n" ).map { |l| l.strip }.join( "\n" )
    end

  end

end
