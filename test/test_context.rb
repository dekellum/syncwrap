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

class TestContext < MiniTest::Unit::TestCase
  include SyncWrap

  def sp
    @sp ||= Space.new
  end

  class TestContext < Context
    attr_accessor :run_args

    def run_shell!( command, args )
      @run_args = [ command, args ]
    end
  end

  def test_context_queue
    host = sp.host( 'localhost' )
    ctx = TestContext.new( host )

    ctx.with do
      ctx.sh( "c1", user: :root )
      assert_nil( ctx.run_args )
      ctx.sh( "c2", user: :root )
      assert_nil( ctx.run_args )
      ctx.flush
      assert_equal( %w[c1 c2], ctx.run_args[0] )
      assert_equal( { user: :root }, ctx.run_args[1] )
    end
  end

  def test_context_flush_at_end
    host = sp.host( 'localhost' )
    ctx = TestContext.new( host )

    ctx.with do
      ctx.sh( "c1", user: :root )
      ctx.sh( "c2", user: :root )
      assert_nil( ctx.run_args )
    end
    assert_equal( %w[c1 c2], ctx.run_args[0] )
  end

  def test_context_flush_on_opts_change
    host = sp.host( 'localhost' )
    ctx = TestContext.new( host )

    ctx.with do
      ctx.sh( "c1", user: :root )
      assert_nil( ctx.run_args )
      ctx.sh( "c2" )
      assert_equal( %w[c1], ctx.run_args[0] )
    end
    assert_equal( %w[c2], ctx.run_args[0] )
  end

  def test_context_with_close
    host = sp.host( 'localhost' )
    ctx = TestContext.new( host )

    ctx.with do
      ctx.sh( "c1-", close: "-c3" ) do
        ctx.sh( "c2" )
        assert_nil( ctx.run_args )
      end
      assert_nil( ctx.run_args )
    end
    assert_equal( %w[c1- c2 -c3], ctx.run_args[0] )
  end

  def test_context_nesting_error
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
