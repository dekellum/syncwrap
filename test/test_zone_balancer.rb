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

class TestZoneBalancer < MiniTest::Unit::TestCase
  include SyncWrap

  def test
    sp = Space.new
    zb = ZoneBalancer
    sp.with do
      f = zb.zone( %w[a b c], [:r2] )
      assert_equal( 'a', f.call )

      sp.host( 'h1', :r1, :r2,  availability_zone: 'a' )
      sp.host( 'h2', :r2, availability_zone: 'b' )
      sp.host( 'h3', :r2, availability_zone: 'a' )
      sp.host( 'h4', :r3, availability_zone: 'b' )

      assert_equal( 'c', f.call )
      assert_equal( 'c', zb.next_zone( %w[a b c], [:r2] ) )
      assert_equal( 'b', zb.next_zone( %w[a b], [:r2] ) )
      assert_equal( 'b', zb.next_zone( %w[a b c], [:r1] ) )
      assert_equal( 'a', zb.next_zone( %w[a b c], [:rempty] ) )
      assert_equal( 'c', zb.next_zone( %w[a b c] ) )

    end
  end
end
