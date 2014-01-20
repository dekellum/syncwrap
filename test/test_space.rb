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

require 'syncwrap'

class TestSpace < MiniTest::Unit::TestCase
  include SyncWrap

  def sp
    @sp ||= Space.new
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
    def install
    end

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
    assert_equal( c1, host.component( CompOne ) )
    assert_equal( c2b, host.component( CompTwo ) ) #last instance
  end

  def test_component_dynamic_binding
    c1 = CompOne.new
    c2 = CompTwo.new
    c3 = CompThree.new
    sp.role( :test, c1, c2, c3 )
    host = sp.host( 'localhost', :test )

    Context.new( host ).with do
      assert_equal( 42, c3.bar )
      assert_raises( NameError, NoMethodError ) { c1.unresolved }
    end

    assert_raises( NameError, NoMethodError ) { c2.goo }
  end

end