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

require 'syncwrap/rsync'

class TestRsync < MiniTest::Unit::TestCase
  include SyncWrap

  class TestWrapper
    include SyncWrap::Rsync

    attr_reader :last_args

    def capture3( args )
      @last_args = args
      [ 0, [] ]
    end

  end

  def test_rsync_args
    w = TestWrapper.new
    cargs = %w[rsync -i -r -l -p -c -b]

    w.rsync( 'testhost', 'other/lang.sh', '/etc/' )

    assert_equal( cargs + [ 'other/lang.sh',
                            'testhost:/etc/' ],
                  w.last_args )

    w.rsync( 'testhost', 'etc/profile.d/lang.sh' )

    assert_equal( cargs + [ 'etc/profile.d/lang.sh',
                            'testhost:/etc/profile.d/' ],
                  w.last_args )

    w.rsync( 'testhost', 'etc/profile.d/' )

    assert_equal( cargs + [ 'etc/profile.d/',
                            'testhost:/etc/profile.d/' ],
                  w.last_args )

    w.rsync( 'testhost', 'etc/profile.d' )

    assert_equal( cargs + [ 'etc/profile.d',
                            'testhost:/etc/' ],
                  w.last_args )

    w.rsync( 'testhost', 'etc/profile.d/lang.sh', :user => 'root' )

    assert_equal( cargs + [ '--rsync-path=sudo rsync',
                            'etc/profile.d/lang.sh',
                            'testhost:/etc/profile.d/'],
                  w.last_args )

    w.rsync( 'testhost', 'etc/profile.d/lang.sh', :user => 'runr' )

    assert_equal( cargs + [ '--rsync-path=sudo -u runr rsync',
                            'etc/profile.d/lang.sh',
                            'testhost:/etc/profile.d/'],
                  w.last_args )

    w.rsync( 'testhost', 'etc/profile.d/lang.sh', :excludes => :dev )

    assert_equal( cargs + [ '--cvs-exclude',
                            'etc/profile.d/lang.sh',
                            'testhost:/etc/profile.d/' ],
                  w.last_args )
  end

end
