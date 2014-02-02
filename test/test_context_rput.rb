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

require 'syncwrap'

class TestContextRput < MiniTest::Unit::TestCase
  include SyncWrap

  TEST_DIR = File.dirname( __FILE__ ).freeze
  SYNC_DIR = File.join( TEST_DIR, 'sync' ).freeze
  SRC_ROOTS = [ SYNC_DIR ].freeze

  def setup
    FileUtils.rm_rf( "#{TEST_DIR}/d1" )
    FileUtils.rm_rf( "#{TEST_DIR}/d2" )
    FileUtils.rm_rf( "#{TEST_DIR}/d3" )
  end

  def sp
    @sp ||= Space.new.tap do |s|
      s.merge_default_options( src_roots: SRC_ROOTS,
                               erb_binding: binding_under_test )
    end
  end

  def test_rput_file
    host = sp.host( 'localhost' )
    ctx = Context.new( host, sp.default_opts )

    2.times do |i|
      ctx.with do
        changes = ctx.rput( 'd1/bar', "#{TEST_DIR}/d2/" )
        if i == 0
          assert_equal( %w[ bar ], changes.map { |c| c[1] } )
        else
          assert_empty( changes )
        end
        assert_equal( IO.read( "#{SYNC_DIR}/d1/bar" ),
                      IO.read( "#{TEST_DIR}/d2/bar" ) )
      end
    end
  end

  def test_rput_erb
    host = sp.host( 'localhost' )
    ctx = Context.new( host, sp.default_opts )

    2.times do |i|
      ctx.with do
        changes = ctx.rput( 'd1/foo.erb', "#{TEST_DIR}/d2/" )
        if i == 0
          assert_equal( %w[ foo ], changes.map { |c| c[1] } )
        else
          assert_empty( changes )
        end
        assert_equal( "barfoobar\n",
                      IO.read( "#{TEST_DIR}/d2/foo" ) )
      end
    end
  end

  def test_rput_file_missing_for_erb
    host = sp.host( 'localhost' )
    ctx = Context.new( host, sp.default_opts )
    assert_raises( SourceNotFound ) do
      ctx.rput( 'd1/foo', "#{TEST_DIR}/d2/" )
    end
  end

  def test_rput_missing_dir
    host = sp.host( 'localhost' )
    ctx = Context.new( host, sp.default_opts )
    assert_raises( SourceNotFound ) do
      ctx.rput( 'nodir/', "#{TEST_DIR}/" )
    end
  end

  def test_rput_contents_with_erb
    host = sp.host( 'localhost' )
    ctx = Context.new( host, sp.default_opts )

    2.times do |i|
      ctx.with do
        changes = ctx.rput( 'd1/', "#{TEST_DIR}/d2" )
        if i == 0
          assert_equal( %w[ ./ bar foo ], changes.map { |c| c[1] } )
        else
          assert_empty( changes )
        end
        assert_equal( IO.read( "#{SYNC_DIR}/d1/bar" ),
                      IO.read( "#{TEST_DIR}/d2/bar" ) )
        assert_equal( "barfoobar\n",
                      IO.read( "#{TEST_DIR}/d2/foo" ) )
      end
    end
  end

  def test_rput_dir_with_erb
    host = sp.host( 'localhost' )
    ctx = Context.new( host, sp.default_opts )

    2.times do |i|
      ctx.with do
        changes = ctx.rput( 'd1', "#{TEST_DIR}" )
        if i == 0
          assert_equal( %w[ d1/ d1/bar d1/foo ], changes.map { |c| c[1] } )
        else
          assert_empty( changes )
        end
        assert_equal( IO.read( "#{SYNC_DIR}/d1/bar" ),
                      IO.read( "#{TEST_DIR}/d1/bar" ) )
        assert_equal( "barfoobar\n",
                      IO.read( "#{TEST_DIR}/d1/foo" ) )
      end
    end
  end

  def test_rput_subdir_with_erb
    host = sp.host( 'localhost' )
    ctx = Context.new( host, sp.default_opts )

    2.times do |i|
      ctx.with do
        changes = ctx.rput( 'd3', "#{TEST_DIR}" )
        if i == 0
          assert_equal( %w[ d3/ d3/d2/ d3/d2/bar d3/d2/foo ],
                        changes.map { |c| c[1] } )
        else
          assert_empty( changes )
        end
        assert_equal( IO.read( "#{SYNC_DIR}/d3/d2/bar" ),
                      IO.read( "#{TEST_DIR}/d3/d2/bar" ) )
        assert_equal( "barfoobar\n",
                      IO.read( "#{TEST_DIR}/d3/d2/foo" ) )
      end
    end
  end

  def test_rput_subdir_contents_with_erb
    host = sp.host( 'localhost' )
    ctx = Context.new( host, sp.default_opts )

    2.times do |i|
      ctx.with do
        changes = ctx.rput( 'd3/', "#{TEST_DIR}" )
        if i == 0
          assert_equal( %w[ d2/ d2/bar d2/foo ], changes.map { |c| c[1] } )
        else
          assert_empty( changes )
        end
        assert_equal( IO.read( "#{SYNC_DIR}/d3/d2/bar" ),
                      IO.read( "#{TEST_DIR}/d2/bar" ) )
        assert_equal( "barfoobar\n",
                      IO.read( "#{TEST_DIR}/d2/foo" ) )
      end
    end
  end

  def binding_under_test
    var = "foo"
    binding
  end

end
