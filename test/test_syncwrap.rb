#!/usr/bin/env jruby
#.hashdot.profile += jruby-shortlived

#--
# Copyright (c) 2011-2012 David Kellum
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

require 'syncwrap/java'
require 'syncwrap/hashdot'
require 'syncwrap/jruby'
require 'syncwrap/iyyov'
require 'syncwrap/geminabox'
require 'syncwrap/ec2'
require 'syncwrap/ubuntu'
require 'syncwrap/rhel'
require 'syncwrap/postgresql'
require 'syncwrap/remote_task'

class TestSyncWrap < MiniTest::Unit::TestCase

  class EveryWrapper
    include SyncWrap::Java
    include SyncWrap::Hashdot
    include SyncWrap::JRuby
    include SyncWrap::Iyyov
    include SyncWrap::Geminabox
    include SyncWrap::Ubuntu
    include SyncWrap::EC2
    include SyncWrap::PostgreSQL
  end

  def test_init
    w = EveryWrapper.new
    assert_equal( '/usr/local', w.common_prefix,
                  'Common#initialize should run for defaults' )
    assert_equal( 'runr', w.user_run,
                  'UserRun#initialize should run for defaults' )
    assert_equal( '1.1.4', w.iyyov_version,
                  'Iyyov#initialize should run for defaults' )
  end

  def test_no_remoting_module
    w = EveryWrapper.new
    assert_raises( RuntimeError, <<-MSG ) { w.run( 'ls' ) }
      Should raise when no remoting module is included.
    MSG
  end

  class CommonWrapper
    include SyncWrap::Common

    attr_reader :last_args

    def rsync( *args )
      @last_args = args
    end

    def target_host
      'testhost'
    end

  end

  def test_rput
    w = CommonWrapper.new

    w.rput( 'other/lang.sh', '/etc/' )

    assert_equal( [ 'other/lang.sh',
                    'testhost:/etc/' ],
                  w.last_args )

    w.rput( 'etc/profile.d/lang.sh' )

    assert_equal( [ 'etc/profile.d/lang.sh',
                    'testhost:/etc/profile.d/' ],
                  w.last_args )

    w.rput( 'etc/profile.d/' )

    assert_equal( [ 'etc/profile.d/',
                    'testhost:/etc/profile.d/' ],
                  w.last_args )

    w.rput( 'etc/profile.d' )

    assert_equal( [ 'etc/profile.d',
                    'testhost:/etc/' ],
                  w.last_args )

    w.rput( 'etc/profile.d/lang.sh', :user => 'root' )

    assert_equal( [ '--rsync-path=sudo rsync',
                    'etc/profile.d/lang.sh',
                    'testhost:/etc/profile.d/'],
                  w.last_args )

    w.rput( 'etc/profile.d/lang.sh', :user => 'runr' )

    assert_equal( [ '--rsync-path=sudo -u runr rsync',
                    'etc/profile.d/lang.sh',
                    'testhost:/etc/profile.d/'],
                  w.last_args )

    w.rput( 'etc/profile.d/lang.sh', :excludes => :dev )

    assert_equal( [ '--cvs-exclude',
                    'etc/profile.d/lang.sh',
                    'testhost:/etc/profile.d/' ],
                  w.last_args )
  end

  class RemoteTaskWrapper
    include SyncWrap::RemoteTask
  end

  class TestTask
    attr_accessor :last_args

    def with
      Thread.current[ :task ] = self
      yield self
    ensure
      Thread.current[ :task ] = nil
    end

    def run( *args )
      @last_args = args
    end

    alias sudo run
  end

  def test_remote_not_in_task
    w = RemoteTaskWrapper.new
    assert_raises( RuntimeError ) { w.run( 'foo' ) }
  end

  def test_run
    w = RemoteTaskWrapper.new
    TestTask.new.with do |t|
      w.run( 'foo' )
      assert_equal( [ 'foo' ], t.last_args )

      w.run( 'foo', 'bar', :opt => :bar )
      assert_equal( [ 'foo', 'bar' ], t.last_args )

      w.run <<-SH
        mkdir -p foo
        touch foo/goo
      SH
      assert_equal( [ [ 'set -e',
                        'mkdir -p foo',
                        'touch foo/goo' ].join( $/ ) ],
                    t.last_args )
    end
  end

  def test_sudo
    w = RemoteTaskWrapper.new
    TestTask.new.with do |t|
      w.sudo( 'foo' )
      assert_equal( [ 'sh -c "foo"' ], t.last_args.flatten.compact )

      w.sudo( 'foo', :shell => false )
      assert_equal( [ 'foo' ], t.last_args.flatten.compact )

      w.sudo( 'foo', 'bar', :user => 'postgres' )
      assert_equal( [ '-u', 'postgres', 'sh -c "foo bar"' ],
                    t.last_args.flatten.compact )

      w.sudo <<-SH
        mkdir -p foo
        touch foo/goo
      SH

      assert_equal( [ "sh -c \"set -e\nmkdir -p foo\ntouch foo/goo\"" ],
                    t.last_args.flatten.compact )
    end
  end

end
