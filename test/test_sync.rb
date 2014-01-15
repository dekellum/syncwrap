#!/usr/bin/env jruby
#.hashdot.profile += jruby-shortlived

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

require 'rubygems'
require 'bundler/setup'

require 'minitest/unit'
require 'minitest/autorun'

require 'syncwrap/shell'
require 'syncwrap/rsync'

module SyncWrap

  class Component
    def initialize( opts = {} )
      super()
      opts.each do |name,val|
        send( name.to_s + '=', val )
      end
    end

    def host
      ctx.host
    end

    def sh( command, opts = {}, &block )
      ctx.sh( command, opts, block )
    end

    # Equivalent to sh( command, user: :root )
    def sudo( command, opts = {}, &block )
      sh( command, opts.merge( user: :root ), block )
    end

    # Equivalent to sh( command, user: run_user ) where run_user would
    # typically come from RunUser.
    def rudo( command, opts = {}, &block )
      sh( command, opts.merge( user: run_user ), block )
    end

    def rput( *args )
      ctx.rput( *args )
    end

    def flush
      ctx.flush
    end

    def method_missing( meth, *args, &block )
      below = false
      host && host.components.reverse_each do |comp|
        if comp == self
          below = true
        elsif below
          if comp.respond_to?( meth )
            return comp.send( meth, *args, &block )
          end
        end
      end
      super
    end

    private

    def ctx
      Context.current or raise "ctx called out of SyncWrap::Context"
    end

  end

  class NestingError < RuntimeError
  end

  class Context
    include Shell
    include Rsync

    class << self
      def current
        Thread.current[:syncwrap_context]
      end

      def swap( ctx )
        old = current
        Thread.current[:syncwrap_context] = ctx
        old
      end
    end

    attr_reader :host

    def initialize( host )
      @host = host
      reset_queue
      @queue_locked = false
      super()
    end

    def with
      prior = Context.swap( self )
      yield
      flush
    ensure
      Context.swap( prior )
    end

    # Put files or entire directories to host via
    # SyncWrap::Rsync::rsync (see details including options).
    # Any queued commands are flushed beforehand, to avoid ambiguous
    # order of remote changes.
    def rput( *args )
      flush
      rsync( host.name, *args )
    end

    # Enqueue a shell command to be run on host.
    def sh( command, opts = {} )
      opts = opts.dup
      close = opts.delete( :close )

      flush if opts != @queued_opts #may still be a no-op

      @queued_cmd << command
      @queued_opts = opts

      if close
        prev, @queue_locked = @queue_locked, true
      end

      begin
        yield if block_given?
        @queued_cmd << close if close
      ensure
        @queue_locked = prev if close
      end
    end

    def flush
      if @queued_cmd.length > 0
        begin
          if @queue_locked
            raise NestingError, 'Queue at flush: ' + @queued_cmd.join( '\n' )
          end
          run_shell!( host.name, @queued_cmd, @queued_opts )
        ensure
          reset_queue
        end
      end
    end

    private

    def reset_queue
      @queued_cmd = []
      @queued_opts = {}
    end

  end

  class Host

    attr_reader :space
    attr_reader :name

    # FIXME: Short name, long name, or IP?

    def initialize( space, name )
      @space = space
      @name = name
      @contents = [ :all ]
    end

    def add( *args )
      args.each do |arg|
        case( arg )
        when Symbol
          @contents << arg unless @contents.include?( arg )
        when Component
          @contents << arg
        else
          raise "Invalid host #{name} addition: #{c.inspect}"
        end
      end
    end

    def roles
      @contents.select { |c| c.is_a?( Symbol ) }
    end

    def components
      @contents.map { |c| c.is_a?( Symbol ) ? space.role( c ) : c }.flatten
    end

    def component( clz )
      components.reverse.find { |c| c.kind_of?( clz ) }
    end

  end

  class Space

    def initialize
      @roles = Hash.new { |h,k| h[k] = [] }
      @hosts = {}
    end

    # Define/access a Role by symbol
    # Additional args are interpreted as Components to add to this
    # role.
    def role( symbol, *args )
      @roles[ symbol.to_sym ] += args.flatten.compact
    end

    # Define/access a Host by name
    # Additional args are interpreted as role symbols or (direct)
    # Components to add to this Host. Each role will only be added
    # once. A final Hash argument is interpreted as and reserved for
    # future options.
    def host( name, *args )
      opts = args.pop if args.last.is_a?( Hash )
      host = @hosts[ name ] ||= Host.new( self, name )
      host.add( *args )
      host
    end

    # FIXME: misc default args for ssh, sudo, i.e:
    # sudo_flags: ['-H']
    # ssh_flags: %w[ -i ./key.pem -l ec2-user ]
    # Option to use example ssh-flags for Users setup only?

    # FIXME: Host name to ssh name strategies go here

    # FIXME: Progamatic interface for execution
  end

end

class TestSync < MiniTest::Unit::TestCase
  include SyncWrap

  class CompOne < Component
    def install
    end

    def foo
      42
    end

    def unresolved
      goo
    end
  end

  class CompTwo < Component
    def install
    end

    def goo
      foo
    end
  end

  def test_host_roles
    sp = Space.new
    sp.host( 'localhost' )
    assert_equal( 'localhost', sp.host( 'localhost' ).name )

    # :all always first role
    assert_equal( [ :all ], sp.host( 'localhost' ).roles )

    # :all remains first
    sp.host( 'localhost', :test )
    assert_equal( [ :all, :test ], sp.host( 'localhost' ).roles )

    # Roles only added once
    sp.host( 'localhost', :test, :all )
    assert_equal( [ :all, :test ], sp.host( 'localhost' ).roles )
  end

  def test_role_components
    sp = Space.new
    c1 = CompOne.new
    c2 = CompTwo.new
    c2b = CompTwo.new
    sp.role( :test, c1, c2 )
    assert_equal( [ c1, c2 ], sp.role( :test ) )

    host = sp.host( 'localhost', :test )
    sp.role( :test, c2b ) # After assigned to host
    assert_equal( [ c1, c2, c2b ], sp.role( :test ) )
    assert_equal( [ c1, c2, c2b ], host.components )

    assert_equal( c1, host.component( CompOne ) )
    assert_equal( c2b, host.component( CompTwo ) ) #last instance
  end

  def test_host_direct_components
    sp = Space.new
    c1 = CompOne.new
    c2 = CompTwo.new
    sp.role( :test, c2 )
    assert_equal( [ c2 ], sp.role( :test ) )

    c2b = CompTwo.new
    host = sp.host( 'localhost', c1, :test, c2b )
    assert_equal( [ c1, c2, c2b ], host.components )
    assert_equal( c1, host.component( CompOne ) )
    assert_equal( c2b, host.component( CompTwo ) ) #last instance
  end

  def test_context_dynamic_binding
    sp = Space.new
    c1 = CompOne.new
    c2 = CompTwo.new
    sp.role( :test, c1, c2 )
    host = sp.host( 'localhost', :test )

    assert_raises( RuntimeError ) { c2.goo }
    Context.new( host ).with do
      assert_equal( 42, c2.goo )
      assert_raises( NameError ) { c1.unresolved }
    end
  end

  class TestContext < Context
    attr_accessor :run_args

    def run_shell!( host, command, args )
      @run_args = [ host, command, args ]
    end
  end

  def test_context_queue
    sp = Space.new
    host = sp.host( 'localhost' )
    ctx = TestContext.new( host )

    ctx.with do
      ctx.sh( "c1", user: :root )
      assert_nil( ctx.run_args )
      ctx.sh( "c2", user: :root )
      assert_nil( ctx.run_args )
      ctx.flush
      assert_equal( 'localhost', ctx.run_args[0] )
      assert_equal( %w[c1 c2], ctx.run_args[1] )
      assert_equal( { user: :root }, ctx.run_args[2] )
    end
  end

  def test_context_flush_at_end
    sp = Space.new
    host = sp.host( 'localhost' )
    ctx = TestContext.new( host )

    ctx.with do
      ctx.sh( "c1", user: :root )
      ctx.sh( "c2", user: :root )
      assert_nil( ctx.run_args )
    end
    assert_equal( %w[c1 c2], ctx.run_args[1] )
  end

  def test_context_flush_on_opts_change
    sp = Space.new
    host = sp.host( 'localhost' )
    ctx = TestContext.new( host )

    ctx.with do
      ctx.sh( "c1", user: :root )
      assert_nil( ctx.run_args )
      ctx.sh( "c2" )
      assert_equal( %w[c1], ctx.run_args[1] )
    end
    assert_equal( %w[c2], ctx.run_args[1] )
  end

  def test_context_with_close
    sp = Space.new
    host = sp.host( 'localhost' )
    ctx = TestContext.new( host )

    ctx.with do
      ctx.sh( "c1-", close: "-c3" ) do
        ctx.sh( "c2" )
        assert_nil( ctx.run_args )
      end
      assert_nil( ctx.run_args )
    end
    assert_equal( %w[c1- c2 -c3], ctx.run_args[1] )
  end

  def test_context_nesting_error
    sp = Space.new
    host = sp.host( 'localhost' )
    ctx = TestContext.new( host )

    assert_raises( NestingError ) do
      ctx.with do
        ctx.sh( "c1-", close: "-c3" ) do
          ctx.sh( "c2", user: :root  )
        end
      end
    end
    assert_nil( ctx.run_args )
  end

end
