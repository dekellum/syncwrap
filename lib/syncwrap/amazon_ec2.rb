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

    def profile( symbol, profile )
      @profiles[symbol] = profile
    end

    def import_hosts( regions, output_file )
      hlist = import_host_props( regions )
      unless hlist.empty?
        File.open( output_file, "a" ) do |out|
          puts "# Import of #{regions.join ','} on #{Time.now.utc.iso8601}"
          puts

          hlist.each do |props|
            props[:name] ||= props[:id].to_s
            host = Host.new( space, props )
            roles = host.roles.map { |s| ':' + s.to_s }.join ','
            roles << ',' unless roles.empty?
            props = host.props.map do |key,val|
              "#{key}: #{val}" unless key == :name
            end.compact.join ','

            out.puts "host( '#{host.name}', #{roles}"
            out.puts "      #{props} )"
          end
        end
      end
    end

  end

end
