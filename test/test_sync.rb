#!/usr/bin/env jruby
#.hashdot.profile += jruby-shortlived

#--
# Copyright (c) 2011-2013 David Kellum
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

    def sh( command, opts = {} )
      ctx.sh( command, opts )
    end

    # Equivalent to sh( command, user: :root )
    def sudo( command, opts = {} )
      sh( command, opts.merge( user: :root ) )
    end

    # Equivalent to sh( command, user: run_user ) where run_user would
    # typically come from RunUser.
    def rudo( command, opts = {} )
      sh( command, opts.merge( user: run_user ) )
    end

    def method_missing( meth, *args, &block )
      below = false
      host.components.reverse_each do |comp|
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
      Context.current or
        raise "Called out of SyncWrap::Context"
    end

  end

  class Context
    include Shell

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
      super()
    end

    def with
      prior = Context.swap( self )
      yield
    ensure
      Context.swap( prior )
    end

    def sh( command, opts = {} )
      run_shell(! host, command, opts )
    end

  end

  class Role

    attr_accessor :components

    def initialize
      @components = []
    end

  end

  class Host

    attr_reader :name
    attr_accessor :roles

    def initialize( name, roles = [] )
      @name = name
      @roles = roles
    end

    def components
      # FIXME: Allow hosts to take components direct?
      # @components ||= []
      roles.map { |r| r.components }.flatten
    end

    def component( clz )
      components.reverse.find { |c| c.kind_of?( clz ) }
    end

  end

  class Space

    def initialize
      @roles = {}
      @hosts = {}

      role( :all )
    end

    # Define/access a Role by symbol
    def role( symbol )
      @roles[ symbol.to_sym ] ||= Role.new
    end

    # Define/access a Host by name
    # Additional args are intpreted as Roles or Role symbols.  These
    # will be appended to the new or existing host's roles.
    # A final Hash argument is interpreted as and reserved for options
    # FIXME: Short name, long name, or IP?
    def host( name, *args )
      opts = args.pop if args.last.is_a?( Hash )
      host = @hosts[ name ] ||= Host.new( name, [ role(:all) ] )
      if !args.empty?
        host.roles |= args.map { |n| n.is_a?( Role ) ? n : role( n ) }
      end
      host
    end

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
    assert_equal( [ sp.role(:all) ], sp.host( 'localhost' ).roles )
    sp.host( 'localhost', :test )
    assert_equal( [ sp.role(:all), sp.role(:test) ],
                  sp.host( 'localhost' ).roles )
  end

  def test_role_components
    sp = Space.new
    c1 = CompOne.new
    c2 = CompTwo.new
    c2b = CompTwo.new
    sp.role( :test ).components = [ c1, c2 ]
    sp.role( :test ).components << c2b
    assert_equal( [ c1, c2, c2b ], sp.role( :test ).components )

    host = sp.host( 'localhost', :test )

    assert_equal( [ c1, c2, c2b ], host.components )
    assert_equal( c1, host.component( CompOne ) )
    assert_equal( c2b, host.component( CompTwo ) )
  end

  def test_context
    sp = Space.new
    c1 = CompOne.new
    c2 = CompTwo.new
    sp.role( :test ).components = [ c1, c2 ]
    host = sp.host( 'localhost', :test )

    assert_raises( RuntimeError ) { c2.goo }
    Context.new( host ).with do
      assert_equal( 42, c2.goo )
      assert_raises( NameError ) { c1.unresolved }
    end
  end

end
