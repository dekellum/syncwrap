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

require 'thread'

require 'syncwrap/base'
require 'syncwrap/component'
require 'syncwrap/context'
require 'syncwrap/host'
require 'syncwrap/formatter'

module SyncWrap

  # Base class for all SyncWrap exception types
  class SyncError < RuntimeError
  end

  # Error in the context in which a component is used
  class ContextError < SyncError
  end

  # Error in use of the Context#sh block form (:close option) with
  # a nested flush or change in options.
  class NestingError < SyncError
  end

  # Source specified in rput can not be found in :sync_paths
  class SourceNotFound < SyncError
  end

  # Context#sh or derivatives failed with non-accepted exit code.
  # Note the error may be delayed until the next Context#flush.
  class CommandFailure < SyncError
  end

  # Serves as the container for #hosts and roles and provides the top
  # level #execute.
  class Space

    # Return the current space, as setup within a Space#with block, or
    # raise something fierce.
    def self.current
      Thread.current[:syncwrap_current_space] or
        raise "Space.current called outside of Space#with/thread"
    end

    # Default options, for use including Component#rput, Component#sh,
    # and #execute (see Options details). The CLI uses this, for
    # example, to set :verbose => true (from --verbose) and
    # :shell_verbose => :x (from --expand-shell). In limited cases it
    # may be appropriate to set default overrides in a sync.rb.
    attr_reader :default_options

    attr_reader :formatter #:nodoc:

    def initialize
      @roles = Hash.new { |h,k| h[k] = [] }
      @hosts = {}
      @default_options = {
        coalesce: true,
        sh_verbose: :v,
        sync_paths: [ File.join( SyncWrap::GEM_ROOT, 'sync' ) ] }
      @formatter = Formatter.new
    end

    # Load the specified file path as per a sync.rb, into this
    # Space. If relative, path is assumed to be relative to the caller
    # (i.e. Rakefile, etc.) as with the conventional 'sync' directory.
    def load_sync_file_relative( fpath = './sync.rb' )
      load_sync_file( path_relative_to_caller( fpath, caller ) )
    end

    # Load the specified filename as per a sync.rb, into this Space.
    # This uses a #with block internally.
    def load_sync_file( filename )
      require 'syncwrap/main'
      with do
        load( filename, true )
        # This is true -> wrapped to avoid pollution of sync
        # namespace. This is particularly important given the dynamic
        # binding scheme of components. If not done, top-level
        # methods/vars in sync.rb would have precidents over
        # component methods.
      end
    end

    # Make self the Space.current inside of block.
    def with
      prior = Thread.current[:syncwrap_current_space]
      raise "Invalid Space#with nesting!" if prior && prior != self
      begin
        Thread.current[:syncwrap_current_space] = self
        yield self
      ensure
        Thread.current[:syncwrap_current_space] = prior
      end
    end

    # Merge the specified options to default_options
    def merge_default_options( opts )
      @default_options.merge!( opts )
      nil
    end

    # Prepend the given directory path to front of the :sync_paths
    # list. If relative, path is assumed to be relative to the caller
    # (i.e. sync.rb) as with the conventional 'sync'
    # directory. Returns a copy of the resultant sync_paths list.
    def prepend_sync_path( rpath = 'sync' )
      rpath = path_relative_to_caller( rpath, caller )

      roots = default_options[ :sync_paths ]
      roots.delete( rpath ) # don't duplicate but move to front
      roots.unshift( rpath )
      roots.dup #return a copy
    end

    # Define/access a Role by symbol.
    # Additional args are interpreted as Components to add to this
    # role.
    def role( symbol, *args )
      if args.empty?
        @roles[ symbol.to_sym ]
      else
        @roles[ symbol.to_sym ] += args.flatten.compact
      end
    end

    # Define/access a Host by name
    # Additional args are interpreted as role symbols or (direct)
    # Components to add to this Host. Each role will only be added
    # once. A final Hash argument is interpreted as and reserved for
    # future options.
    def host( name, *args )
      opts = args.last.is_a?( Hash ) && args.pop || {}
      host = @hosts[ name ] ||= Host.new( self, name )
      host.add( *args )
      host
    end

    # All Host instances, in order added.
    def hosts
      @hosts.values
    end

    # Return an ordered, unique set of component classes, direct or via
    # roles, currently contained by the specified hosts or all hosts.
    def component_classes( hs = hosts )
      hs.
        map { |h| h.components }.
        flatten.
        map { |comp| comp.class }.
        uniq
    end

    # Returns a new component_plan from plan, looking up any Class
    # string names and using :install for any missing methods:
    #
    # \[ [ Class | String, Symbol? ] ... ] -> [ [ Class, Symbol ] ... ]
    #
    # Class name lookup is by unqualified matching against
    # #component_classes (already added to hosts of this space.) If
    # such String match is ambiguous or not found, a RuntimeError is
    # raised.
    def resolve_component_plan( plan )
      classes = component_classes
      plan.map do |clz,mth|
        if clz.is_a?( String )
          found = classes.select { |cc| cc.name =~ /(^|::)#{clz}$/ }
          if found.length == 1
            clz = found.first
          else
            raise "Class \"#{clz}\" ambiguous or not found: #{found.inspect}"
          end
        end
        [ clz, mth && mth.to_sym || :install ]
      end
    end

    # Execute components based on a host_list (default all), a
    # component_plan (default :install on all components), and with
    # any additional options (merged with default_options).
    #
    # === Options
    #
    # The following options are specifically handled by execute:
    #
    # :colorize:: If false, don't color diagnostic output to stdout
    #             (default: true)
    #
    # :threads:: The number of threads on which to execute. Each host is
    #            executed with a single thread.
    #            (Default: the number of hosts, maximum concurrency)
    #
    def execute( host_list = hosts, component_plan = [], opts = {} )
      opts = default_options.merge( opts )
      @formatter.colorize = ( opts[ :colorize ] != false )
      component_plan = resolve_component_plan( component_plan )

      if opts[ :threads ] && host_list.length > opts[ :threads ]
        queue = Queue.new
        host_list.each { |host| queue.push( host ) }
        threads = opts[ :threads ].times.map do
          Thread.new( queue, component_plan, opts ) do |q, cp, o|
            success = true
            begin
              while host = q.pop( true ) # non-block
                r = execute_host( host, cp, o )
                success &&= r
              end
            rescue ThreadError
              #exit, from queue being empty
            end
            success
          end
        end
      else
        threads = host_list.map do |host|
          Thread.new( host, component_plan, opts ) do |h, cp, o|
            execute_host( h, cp, o )
          end
        end
      end
      threads.inject(true) { |s,t| t.value && s }
      # Note: Unhandled (i.e. non-SyncError) exceptions will be
      # propigated and re-raised on call to value above, resulting in
      # standard ruby stack trace and immediate exit.
    end

    # FIXME: Host name to ssh name strategies go here
    def ssh_host_name( host ) # :nodoc:
      host.name
    end

    private

    def execute_host( host, component_plan = [], opts = {} )
      # Important: resolve outside of context
      comp_methods = resolve_component_methods(host.components, component_plan)
      ctx = Context.new( host, opts )
      ctx.with do
        comp_methods.each do |comp, mths|
          success = mths.inject(true) do |s, mth|
            # short-circuit after first non-success
            s && execute_component( ctx, host, comp, mth, opts )
          end
          return false unless success
        end
      end
      true
    rescue SyncError => e
      formatter.sync do
        formatter.write_error( host, e )
      end
      false
    end

    # Given components and plan, return an ordered Array of
    # \[component, [method,...]] to execute. An empty/default plan is
    # interpreted as :install on all components which implement it. If
    # :install is explicitly part of the plan, then it trumps any
    # other methods listed for the same component.
    #
    # Note this must be run out-of-Context to avoid unintended dynamic
    # binding of :install or other methods.
    def resolve_component_methods( components, component_plan = [] )
      components.map do |comp|
        mths = []
        if component_plan.empty?
          mths = [ :install ] if comp.respond_to?( :install )
        else
          found = component_plan.select { |cls,_| comp.kind_of?( cls ) }
          mths = found.map { |_,mth| mth }
          mths = [ :install ] if mths.include?( :install ) #trumps
        end
        [ comp, mths ] unless mths.empty?
      end.compact
    end

    def execute_component( ctx, host, comp, mth, opts )

      if opts[ :flush_component ]
        formatter.sync do
          formatter.write_component( host, comp, mth, "start" )
        end
      end

      comp.send( mth )

      ctx.flush if opts[ :flush_component ]

      formatter.sync do
        formatter.write_component( host, comp, mth,
          opts[ :flush_component ] ? "complete" : "queued" )
      end

      true
    rescue SyncError => e
      formatter.sync do
        if e.is_a?( CommandFailure ) && ! opts[ :flush_component ]
          # We don't know if its really from this component/method
          formatter.write_error( host, e )
        else
          formatter.write_error( host, e, comp, mth )
        end
      end
      false
    end

    def path_relative_to_caller( rpath, clr )
      unless rpath =~ %r{^/}
        from = clr.first =~ /^([^:]+):/ && $1
        rpath = File.expand_path( rpath, File.dirname( from ) ) if from
      end
      rpath
    end

  end

end
