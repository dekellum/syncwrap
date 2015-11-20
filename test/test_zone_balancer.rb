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
    sp.with do
      zb = ZoneBalancer.new( roles: [:r2], zones: %w[ a b c ] )
      f = zb.zone
      sp.host( 'h1', :r1, :r2,  availability_zone: 'a' )
      sp.host( 'h2', :r2, availability_zone: 'b' )
      sp.host( 'h3', :r2, availability_zone: 'a' )
      sp.host( 'h3', :r3, availability_zone: 'b' )
      assert_equal( 'c', zb.next_zone  )
      assert_equal( 'c', f.call  )
    end
  end
end
