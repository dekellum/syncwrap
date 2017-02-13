#--
# Copyright (c) 2011-2017 David Kellum
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
      @comp_roles = []
      @add_roles = []
      @host_patterns = []
      @create_plan = []
      @image_plan = []
      @import_regions = []
      @terminate_hosts = []
      @delete_attached_storage = false
      @ssh_session = nil
      @space = Space.new
    end

    attr_reader :space

    def parse_cmd( args )
      opts = OptionParser.new do |opts|
        opts.banner = <<-TEXT
Usage: syncwrap {options} [Component[.method]] ..."
General options:
TEXT
        opts.summary_width = 30
        opts.summary_indent = "  "

        opts.on( "-f", "--file FILE",
                 "Load FILE for role/host/component/profile",
                 "definitions. (default: './sync.rb')" ) do |f|
          @sw_file = f
        end

        opts.on( "-h", "--hosts PATTERN",
                 "Constrain hosts by name PATTERN",
                 "(may use multiple)" ) do |p|
          @host_patterns << Regexp.new( p )
        end

        opts.on( "-r", "--hosts-with-role ROLE",
                 "Constrain hosts by ROLE (may use multiple)" ) do |r|
          @roles << r.sub(/^:/,'').to_sym
        end

        opts.on( "-R", "--components-in-role ROLE",
                 "Constrain components by ROLE (may use multiple)" ) do |r|
          @comp_roles << r.sub(/^:/,'').to_sym
        end

        opts.on( "-t", "--threads N",
                 "The number of hosts to process concurrently",
                 "(default: all hosts)",
                  Integer ) do |n|
          @options[ :threads ] = n
        end

        opts.on( "-n", "--dryrun",
                 "Run in \"dry run\", or no changes/test mode",
                 "(typically combined with -v)" ) do
          @options[ :dryrun ] = true
        end

        opts.on( "-e", "--each-component",
                 "Flush shell commands after each component" ) do
          @options[ :flush_component ] = true
        end

        opts.on( "--no-coalesce",
                 "Do not coalesce streams (as is the default)" ) do
          @options[ :coalesce ] = false
        end

        opts.on( "--no-color",
                 "Do not colorize output (as is the default)" ) do
          @options[ :colorize ] = false
        end

        opts.on( "-v", "--verbose",
                 "Show details of rput and remote commands" ) do
          @options[ :verbose ] = true
        end

        opts.on( "-c", "--verbose-changes",
                 "Be verbose only about actual rput changes" ) do
          @options[ :verbose_changes ] = true
        end

        opts.on( "-x", "--expand-shell",
                 "Use -x (expand) instead of -v shell output",
                 "(sh_verbose: :x, typically combined with -v)" ) do
          @options[ :sh_verbose ] = :x
        end

        opts.on( "--version",
                 "Show syncwrap version and exit" ) do
          puts "syncwrap: #{SyncWrap::VERSION}"
          exit 0
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

        opts.on( "-S", "--ssh-session HOST",
                 "Only exec an ssh login session on HOST name",
                 "(ssh args can be passed after an '--')" ) do |h|
          @ssh_session = h
        end

        opts.separator( "Provider specific operations and options:" )

        opts.on( "-C", "--create-host P",
                 "Create hosts. P has form: [N*]profile[:name]",
                 "  N: number to create (default: 1)",
                 "  profile: profile name as in sync file",
                 "  name: Host name, or prefix when N>1",
                 "Appends hosts to the sync file and space for",
                 "immediate provisioning." ) do |h|
          first,rest = h.split('*')
          if rest
            count = first.to_i
          else
            count = 1
            rest = first
          end
          profile,name = rest.split(':')
          profile = profile.to_sym
          @create_plan << [ count, profile, name ]
        end

        opts.on( "--create-image PROFILE",
                 "Create a machine image using a temp. host",
                 "of PROFILE, provisioning only that host,",
                 "imaging, and terminating." ) do |profile|
          @image_plan << profile.to_sym
        end

        opts.on( "-a", "--add-role ROLE",
                 "When creating a new host or image, add ROLE",
                 "beyond those specified by the profile",
                 "(may use multiple)" ) do |r|
          @add_roles << r.sub(/^:/,'').to_sym
        end

        opts.on( "--import-hosts REGIONS",
                 "Import hosts form provider 'region' names, ",
                 "append to sync file and exit." ) do |rs|
          @import_regions = rs.split( /[\s,]+/ )
        end

        opts.on( "--terminate-host NAME",
                 "Terminate the specified instance and remove ",
                 "from sync file. WARNING: potential data loss" ) do |name|
          @terminate_hosts << name
        end

        opts.on( "--delete-attached-storage",
                 "When terminating, also delete attached",
                 "volumes which would not otherwise be",
                 "deleted. WARNING: Data WILL be lost!" ) do
          @delete_attached_storage = true
        end

        opts.separator <<-TEXT

By default, runs #install on all Components of all hosts, including
any just created.  This can be limited by specifying --host
PATTERN(s), --hosts-with-role ROLE(s), specific Component[.method](s)
or options above which exit early or have constraints noted.
TEXT

      end

      @component_plan = opts.parse!( args )
      # Usually; but treat these as ssh args if --ssh-session

    rescue OptionParser::ParseError => e
      $stderr.puts e.message
      $stderr.puts opts
      exit 3
    end

    def run( args )
      parse_cmd( args )
      space.load_sync_file( @sw_file )

      if !@import_regions.empty?
        if space.provider
          space.provider.import_hosts( @import_regions, @sw_file )
          exit 0
        else
          raise "No provider set in sync file/registered with Space"
        end
      end

      if !@terminate_hosts.empty?
        space.provider.terminate_hosts( @terminate_hosts,
                                        @delete_attached_storage,
                                        @sw_file )
        exit 0
      end

      if !@image_plan.empty?
        success = nil
        p = space.provider
        @image_plan.each do |profile_key|
          ami,name = p.create_image_from_profile(profile_key, @sw_file) do |host|
            host.add( *@add_roles ) unless @add_roles.empty?
            space.execute( [ host ], [], @options )
          end
          exit( 1 ) unless ami
          puts "Image #{ami} (#{name}) created for profile #{profile_key}"
        end
        exit 0
      end

      @create_plan.each do |count, profile, name|
        space.provider.create_hosts( count, profile, name, @sw_file ) do |host|
          host.add( *@add_roles ) unless @add_roles.empty?
        end
      end

      if @ssh_session
        host = space.get_host( @ssh_session )
        host = space.ssh_host_name( host )
        raise "Host #{@ssh_session} not found in sync file" unless host
        extra_args = @component_plan
        raise "SSH args? #{extra_args.inspect}" if extra_args.first =~ /^[^\-]/
        @component_plan = []
        Kernel.exec( 'ssh', *extra_args, host )
      end

      resolve_hosts
      lookup_component_plan
      resolve_components

      lists = [ @list_components, @list_roles, @list_hosts ].count( true )
      list_components( component_classes, lists > 1 ) if @list_components
      list_roles( @hosts, lists > 1) if @list_roles
      list_hosts( @hosts, lists > 1) if @list_hosts

      exit( 0 ) if lists > 0

      unless @comp_roles.empty?
        @options[ :comp_roles ] = @comp_roles
      end

      success = space.execute( @hosts, @component_plan, @options )
      exit( success ? 0 : 1 )
    end

    def list_components( comp_classes, multi )
      puts "Selected Components:" if multi
      puts short_class_names( comp_classes ).join( ' ')
      puts if multi
    end

    def list_roles( hosts, multi )
      puts "Included Roles:" if multi
      roles = hosts.map( &:roles ).inject([],:|)
      roles &= @comp_roles if !@comp_roles.empty?
      table = roles.map do |role|
        row = [ ':' + role.to_s ]
        classes = space.role( role ).map( &:class )
        row << short_class_names( classes )
      end
      print_table( table )
      puts if multi
    end

    def list_hosts( hosts, multi )
      names = []
      puts "Selected Hosts:" if multi
      table = hosts.map do |host|
        row = [ host.name ]
        row += host.contents.map do |c|
          if c.is_a?( Symbol )
            ':' + c.to_s
          else
            short_class_names( [c.class], names ).first
          end
        end
      end
      print_table( table )
    end

    def print_table( table )
      max_columns = table.map( &:count ).max || 0
      col_widths = max_columns.times.map do |i|
        table.map do |row|
          case row[i]
          when String
            row[i].length
          when Array
            1
          end
        end.compact.max
      end
      wfirst = unless col_widths.empty?
                 col_widths[0] += 4 # Extra pad first col
                 col_widths[0] + 1
               end

      table = table.map do |row|
        row.map do |cell|
          if cell.is_a?( Array )
            l = 0
            cell.inject( String.new ) do |m,i|
              if l == 0 || ( wfirst + l + i.length + 1 < term_width )
                m << i << ' '
                l += i.length + 1
              else
                m << "\n" + (' ' * wfirst)
                m << i << ' '
                l = wfirst + i.length + 1
              end
              m
            end
          else
            cell
          end
        end
      end

      wall = 0
      format = col_widths.inject( String.new ) do |f,w|
        if f.empty? || ( wall + w + 1 < term_width )
          f << "%-#{w}s "
          wall += w + 1
        else
          f[-1,1] = "\n"
          f << ( ' ' * wfirst ) + "%-#{w}s "
          wall = wfirst + w + 1
        end
        f
      end
      table.each do |row|
        row[ max_columns ] = nil
        puts (format % row ).gsub( /\s+$/, '' )
      end
    end

    # Return a new Array of classes mapped to the shortest possible
    # non-duplicate name.
    def short_class_names( classes, names = [] )
      classes.map do |cls|
        segs = cls.name.split( '::' )
        (0...segs.length).reverse_each do |s|
          tn = segs[s..-1].join( '::' )
          if !names.include?( tn )
            break tn
          end
        end
      end
    end

    def lookup_component_plan
      @component_plan.map! do |comp|
        name, meth = comp.split( '.' )
        [ name, meth ]
      end
      @component_plan = space.resolve_component_plan( @component_plan )
    end

    def component_classes
      if @component_plan.empty?
        space.component_classes( @hosts )
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
      @hosts = space.hosts
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

      unless @comp_roles.empty?
        @hosts.select! do |host|
          host.roles.any? { |r| @comp_roles.include?( r ) }
        end
      end
    end

    def term_width
      @term_width ||= ( unix? && (check_stty_width || check_tput_width) ) || 80
    end

    def unix?
       !!( RbConfig::CONFIG['host_os'] =~
           /(aix|darwin|linux|(net|free|open)bsd|cygwin|solaris|irix|hpux)/i )
    end

    def check_stty_width
      s = `stty size 2>/dev/null`
      s &&= s.split[1]
      s &&= s.to_i
      s if s && s >= 30
    rescue
      nil
    end

    def check_tput_width
      s = `tput cols 2>/dev/null`
      s &&= s.to_i
      s if s && s >= 30
    rescue
      nil
    end

  end
end
