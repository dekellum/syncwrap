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

  # Source specified in rput can not be found in :src_roots
  class SourceNotFound < SyncError
  end

  # Context#sh or derivatives failed with non-accepted exit code.
  # Note the error may be delayed until the next Context#flush.
  class CommandFailure < SyncError
  end

  class Space

    # FIXME: document
    attr_reader :default_opts

    attr_reader :formatter

    def initialize
      @roles = Hash.new { |h,k| h[k] = [] }
      @hosts = {}
      @default_opts = {
        coalesce: true,
        sh_verbose: :v,
        src_roots: [ File.join( SyncWrap::GEM_ROOT, 'sync' ) ] }
      @formatter = Formatter.new
    end

    def merge_default_options( opts )
      @default_opts.merge!( opts )
    end

    # Define/access a Role by symbol
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

    # All hosts, in order added.
    def hosts
      @hosts.values
    end

    def execute( host_list = hosts, component_plan = [], opts = {} )
      opts = default_opts.merge( opts )
      @formatter.colorize = ( opts[ :colorize ] != false )

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
    # \[component, [methods]] to execute. An empty/default plan is
    # interpreted as :install on all components which implement it. If
    # :install is explicitly part of the plan, then it trumps any
    # other methods listed for the same component.
    #
    # Note this must be run out-of-Context to avoid unintended dynamic
    # binding of the :install methods, etc.
    def resolve_component_methods( components, component_plan = [] )
      components.map do |comp|
        mths = []
        if component_plan.empty?
          mths = [ :install ] if comp.respond_to?( :install )
        else
          found = component_plan.select { |cls,_| comp.is_a?( cls ) }
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

    # FIXME: Host name to ssh name strategies go here
    def ssh_host_name( host )
      host.name
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

    class << self
      attr_accessor :current
    end

  end

  module Main

    private

    def role( *args )
      Space.current.role( *args )
    end

    def host( *args )
      Space.current.host( *args )
    end

    def options( opts = nil )
      if opts
        Space.current.merge_default_options( opts )
      else
        Space.current.default_opts
      end
    end

  end

end
