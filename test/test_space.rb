#!/usr/bin/env jruby
#.hashdot.profile += jruby-shortlived

#--
# Copyright (c) 2011-2015 David Kellum
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

require_relative 'setup'

require 'syncwrap'

class TestSpace < MiniTest::Unit::TestCase
  include SyncWrap

  def sp
    @sp ||= Space.new.tap do |s|
      class << s
        # for test access:
        public :resolve_component_methods
      end
    end

  end

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
    def goo
      foo
    end
  end

  class CompThree < Component
    def install
    end

    def bar
      goo
    end
  end

  class Turnip
  end

  def test_host_roles
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
    c1 = CompOne.new
    c2 = CompTwo.new
    sp.role( :test, c2 )
    assert_equal( [ c2 ], sp.role( :test ) )

    c2b = CompTwo.new
    host = sp.host( 'localhost', c1, :test, c2b )
    assert_equal( [ c1, c2, c2b ], host.components )
    assert_equal( [ c2 ], host.components_in_roles( [ :test ] ) )
    assert_equal( c1, host.component( CompOne ) )
    assert_equal( c2b, host.component( CompTwo ) ) #last instance
  end

  def test_component_dynamic_binding_direct
    c1 = CompOne.new
    c2 = CompTwo.new
    c3 = CompThree.new
    host = sp.host( 'localhost', c1, c2, c3 )

    Context.new( host ).with do
      assert( c3.respond_to?( :goo ) )
      assert_equal( 42, c3.bar )
      assert( c1.respond_to?( :unresolved ) )
      refute( c1.respond_to?( :goo ) )
      assert_raises( NameError ) { c1.unresolved }
    end

    assert_raises( NameError ) { c2.goo }
  end

  def test_resolve_component_methods
    c1 = CompOne.new
    c2 = CompTwo.new
    c3 = CompThree.new
    host = sp.host( 'localhost', c1, c2, c3 )

    # Note: c2 not here, though in Context, c1's :install is visible
    # to c2.
    refute( c2.respond_to?( :install ) )
    assert_equal( [ [ c1, [:install] ], [ c3, [:install] ] ],
                  sp.resolve_component_methods( host.components, [] ) )
  end

  def test_resolve_component_methods_with_plan
    c1 = CompOne.new
    c2 = CompTwo.new
    c3 = CompThree.new
    host = sp.host( 'localhost', c1, c2, c3 )

    plan = [ [CompOne, :foo], [CompOne, :unresolved], [CompTwo, :goo] ]

    assert_equal( [ [ c1, [:foo, :unresolved] ], [ c2, [:goo] ] ],
                  sp.resolve_component_methods( host.components, plan ) )
  end

  def test_resolve_component_methods_with_plan_trumped
    c1 = CompOne.new
    c2 = CompTwo.new
    c3 = CompThree.new
    host = sp.host( 'localhost', c1, c2, c3 )

    plan = [ [CompOne, :foo], [CompOne, :install], [CompThree, :install] ]

    assert_equal( [ [ c1, [:install] ], [ c3, [:install] ] ],
                  sp.resolve_component_methods( host.components, plan ) )
  end

  def test_component_dynamic_binding_role_plus_direct
    c1 = CompOne.new
    c2 = CompTwo.new
    c3 = CompThree.new
    sp.role( :test, c1, c2 )
    host = sp.host( 'localhost', :test, c3 )

    Context.new( host ).with do
      assert( c3.respond_to?( :goo ) )
      assert_equal( 42, c3.bar )
      assert( c1.respond_to?( :unresolved ) )
      refute( c1.respond_to?( :goo ) )
      assert_raises( NameError ) { c1.unresolved }
    end

    assert_raises( NameError ) { c2.goo }
  end

  def test_component_custom_binding
    c1 = CompOne.new
    c2 = CompTwo.new
    sp.role( :test, c1, c2 )
    host = sp.host( 'localhost', :test )

    Context.new( host ).with do
      t = Turnip.new
      b = c2.send( :custom_binding,
                   { x: 1,
                     str: "yep",
                     bool: true,
                     a: [2, "nest"],
                     obj: t,
                     mth: c1.method(:foo),
                     unresolved: "was" } )
      assert_equal( 1, b.eval( "x" ) )
      assert_equal( "yep", b.eval( "str" ) )
      assert_equal( true,  b.eval( "bool" ) )
      assert_equal( [2, "nest"],  b.eval( "a" ) )
      assert_equal( t, b.eval( "obj" ) )
      assert_equal( 42, b.eval( "mth.call" ) )
      assert_equal( 42, b.eval( "goo" ) ) #dynamic
      assert_equal( "was", b.eval( "unresolved" ) ) #extra, override
      assert_equal( 'localhost', b.eval( "host.name" ) )    #host
      assert_raises( NameError ) { b.eval( "extra_vars" ) } #junk

      # No residual side effects on next call
      b2 = c2.send( :custom_binding )
      assert_raises( NameError ) { b2.eval( "x" ) }
    end
  end

end
