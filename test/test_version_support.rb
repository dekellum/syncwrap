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

require_relative 'setup'

require 'syncwrap/version_support'

class TestVersionSupport < MiniTest::Unit::TestCase
  include SyncWrap::VersionSupport

  def test_to_a
    assert_equal( [ 1 ], version_string_to_a( '1' ) )
    assert_equal( [ 'a' ], version_string_to_a( 'a' ) )
    assert_equal( [ 1, 2 ], version_string_to_a( '1.2' ) )
    assert_equal( [ 1, 'p2' ], version_string_to_a( '1.p2' ) )
    assert_equal( [ 1, 2, 'p3' ], version_string_to_a( '1.2-p3' ) )
  end

  def test_gte
    refute( version_gte?( [0], [1] ) )
    assert( version_gte?( [1], [1] ) )
    assert( version_gte?( [2], [1] ) )

    refute( version_gte?( ['a'], ['b'] ) )
    assert( version_gte?( ['b'], ['b'] ) )
    assert( version_gte?( ['c'], ['b'] ) )

    refute( version_gte?( [0],     [1,0] ) )
    refute( version_gte?( [0,1],   [1,0] ) )
    refute( version_gte?( [1],     [1,0] ) )
    assert( version_gte?( [1,0],   [1,0] ) )
    assert( version_gte?( [1,0,0], [1,0] ) )
    assert( version_gte?( [1,1],   [1,0] ) )

    assert( version_gte?( [1,'a'],   [1,'a'] ) )
    assert( version_gte?( [1,'a',0], [1,'a'] ) )
    assert( version_gte?( [1,'b'],   [1,'a'] ) )

    refute( version_gte?( [1,1], [1,'a'] ) )
  end

  def test_lte
    assert( version_lt?( [0], [1] ) )
    refute( version_lt?( [1], [1] ) )
    refute( version_lt?( [2], [1] ) )
  end

end
