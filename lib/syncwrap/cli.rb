#--
# Copyright (c) 2011-2014 David Kellum
#
# Licensed under the Apache License, Version 2.0 (the "License"); you
# may not use this file except in compliance with the License.  You
# may obtain a copy of the License at
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

require 'optparse'
require 'term/ansicolor'

module SyncWrap

  class CLI

    def initialize
      @sw_file = './sync.rb'
      @options = {}
      @list_hosts = false
      @list_roles = false
      @list_components = false
      @component_plan = []
      @roles = []
      @host_patterns = []
      Space.current = @space = Space.new
    end

    def parse_cmd( args )
      opts = OptionParser.new do |opts|
        opts.banner = "Usage: syncwrap {options} [Component[.method]] ..."

        opts.on( "-e", "--each-component",
                 "Flush shell commands after each component method" ) do
          @options[ :flush_component ] = true
        end

        opts.on( "-f", "--file FILE",
                 "Load FILE for role/host/component definitions",
                 "(default: './sync.rb')" ) do |f|
          @sw_file = f
        end
        opts.on( "-h", "--hosts PATTERN",
                 "Constrain hosts by pattern (may use multiple)" ) do |p|
          @host_patterns << Regexp.new( p )
        end

        opts.on( "-n", "--dryrun",
                 "Run in \"dry run\", or no changes/test mode",
                 "(typically combined with -v)" ) do
          @options[ :dryrun ] = true
        end

        opts.on( "-r", "--hosts-with-role ROLE",
                 "Constrain hosts by role (may use multiple)" ) do |r|
          @roles << r.sub(/^:/,'').to_sym
        end

        opts.on( "-s", "--no-coalesce",
                 "Do not coalesce streams (as is the default)" ) do
          @options[ :coalesce ] = false
        end

        opts.on( "-t", "--threads N",
                 "Specify the number of hosts to process concurrently",
                 "(default: all hosts)",
                  Integer ) do |n|
          @options[ :threads ] = n
        end

        opts.on( "-v", "--verbose",
                 "Show details of local/remote command execution" ) do
          @options[ :verbose ] = true
        end

        opts.on( "--version",
                 "Show syncwrap version and exit" ) do
          puts "syncwrap: #{SyncWrap::VERSION}"
          exit 1
        end

        opts.on( "-x", "--expand-shell",
                 "Use -x (expand) instead of -v shell verbose output",
                 "(sh_verbose: :x, typically combined with -v)" ) do
          @options[ :sh_verbose ] = :x
        end

        opts.on( "--list-components",
                 "List selected components and exit" ) do
          @list_components = true
        end

        opts.on( "--list-roles",
                 "List relevent roles and exit" ) do
          @list_roles = true
        end

        opts.on( "--list-hosts",
                 "List selected hosts and exit" ) do
          @list_hosts = true
        end

        opts.on( "-l", "--list",
                 "List selected roles and hosts, then exit" ) do
          @list_roles = true
          @list_hosts = true
        end

      end
      @component_plan = opts.parse!( args )
    end

    def run( args )
      parse_cmd( args )
      load( @sw_file, true )
      resolve_hosts
      lookup_component_plan
      resolve_components

      lists = [ @list_components, @list_roles, @list_hosts ].count( true )
      list_components( component_classes, lists > 1 ) if @list_components
      list_roles( @hosts, lists > 1) if @list_roles
      list_hosts( @hosts, lists > 1) if @list_hosts

      exit( 0 ) if lists > 0

      @space.execute( @hosts, @component_plan, @options )
    end

    def list_components( comp_classes, multi )
      puts "Selected Components:" if multi
      puts comp_classes.map { |cls| short_cn( cls ) }.join( ' ')
      puts if multi
    end

    def list_roles( hosts, multi )
      puts "Included Roles:" if multi
      roles = hosts.map { |h| h.roles }.inject([],:|)
      table = roles.map do |role|
        [ ':' + role.to_s ] +
          @space.role( role ).map { |c| short_cn( c.class ) }
      end
      print_table( table )
      puts if multi
    end

    def list_hosts( hosts, multi )
      puts "Selected Hosts:" if multi
      table = hosts.map do |host|
        [ host.name ] +
          host.contents.map do |c|
            c.is_a?( Symbol ) ? ':' + c.to_s : short_cn( c.class )
        end
      end
      print_table( table )
    end

    def print_table( table )
      max_columns = table.map { |r| r.count }.max || 0
      col_widths = max_columns.times.map do |i|
        table.map { |row| row[i] && row[i].length }.compact.max
      end
      format = col_widths.inject("") do |f,w|
        if f.empty? #first
          f << "%-#{w}s     "
        else
          f << "%-#{w}s "
        end
      end

      table.each do |row|
        row[ max_columns ] = nil
        puts format % row
      end
    end

    def short_cn( cls )
      cls.name.sub(/^SyncWrap::/,'')
    end

    def lookup_component_plan
      @component_plan.map! do |comp|
        name, meth = comp.split( '.' )
        nameparts = name.split( '::' )
        cls = class_lookup( nameparts )
        [ cls, meth && meth.to_sym || :install ]
      end
    end

    def component_classes
      if @component_plan.empty?
        @space.component_classes( @hosts )
      else
        @component_plan.map { |a| a[0] }
      end
    end

    def resolve_components
      if ! @component_plan.empty?
        @hosts.select! do |host|
          host.components.any? do |comp|
            component_classes.any? { |cc| comp.is_a?( cc ) }
          end
        end
      end
    end

    def resolve_hosts
      @hosts = @space.hosts
      unless @host_patterns.empty?
        @hosts.select! do |host|
          @host_patterns.any? do |pat|
            md = pat.match( host.name )
            md && md[0] == host.name
          end
        end
      end

      unless @roles.empty?
        @hosts.select! do |host|
          host.roles.any? { |r| @roles.include?( r ) }
        end
      end
    end

    def class_lookup( names )
      names.inject( self.class ) do |mod, name|
        mod.const_get( name )
      end
    end

  end
end
