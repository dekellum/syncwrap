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

  VERBOSE = ARGV.include?( '--verbose' )

  TEST_DIR = File.dirname( __FILE__ ).freeze
  SYNC_DIR = File.join( TEST_DIR, 'sync' ).freeze
  SYNC_PATHS = [ SYNC_DIR ].freeze

  def setup
    FileUtils.rm_rf( "#{TEST_DIR}/d1" )
    FileUtils.rm_rf( "#{TEST_DIR}/d2" )
    FileUtils.rm_rf( "#{TEST_DIR}/d3" )
    FileUtils.rm_rf( "#{TEST_DIR}/baz" )
  end

  class TestContext < Context
    attr_accessor :rsync_count

    def initialize( *args )
      @rsync_count = 0
      super
    end
    def rsync( *args )
      @rsync_count += 1
      super
    end
  end

  def sp
    @sp ||= Space.new.tap do |s|
      s.merge_default_options( sync_paths: SYNC_PATHS,
                               erb_binding: binding_under_test )
      s.merge_default_options( verbose: :v ) if VERBOSE
    end
  end

  def test_rput_file
    host = sp.host( 'localhost' )
    2.times do |i|
      ctx = TestContext.new( host, sp.default_options )
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
      assert_equal( 1, ctx.rsync_count )
    end
  end

  def test_rput_file_sudo
    skip unless TestOptions::SAFE_SUDO
    host = sp.host( 'localhost' )
    2.times do |i|
      ctx = TestContext.new( host, sp.default_options )
      ctx.with do
        changes = ctx.rput( 'd1/bar', "#{TEST_DIR}/d2/", user: ENV['USER'] )
        if i == 0
          assert_equal( %w[ bar ], changes.map { |c| c[1] } )
        else
          assert_empty( changes )
        end
        assert_equal( IO.read( "#{SYNC_DIR}/d1/bar" ),
                      IO.read( "#{TEST_DIR}/d2/bar" ) )
      end
      assert_equal( 1, ctx.rsync_count )
    end
  end

  def test_rput_file_sudo_root
    skip unless TestOptions::SAFE_SUDO
    begin
      FileUtils.mkdir_p( "#{TEST_DIR}/root" )
      host = sp.host( 'localhost' )
      2.times do |i|
        ctx = TestContext.new( host, sp.default_options )
        ctx.with do
          changes = ctx.rput( 'd1/bar', "#{TEST_DIR}/root/d2/", user: :root )
          if i == 0
            assert_equal( %w[ bar ], changes.map { |c| c[1] } )
          else
            assert_empty( changes )
          end
          assert_equal( 0, File.stat( "#{TEST_DIR}/root/d2" ).uid )
          assert_equal( 0, File.stat( "#{TEST_DIR}/root/d2/bar" ).uid )
          assert_equal( IO.read( "#{SYNC_DIR}/d1/bar" ),
                        IO.read( "#{TEST_DIR}/root/d2/bar" ) )
        end
        assert_equal( 1, ctx.rsync_count )
      end
    ensure
      system "sudo rm -rf #{TEST_DIR}/root"
    end
  end

  def test_rput_erb_no_suffix
    host = sp.host( 'localhost' )
    2.times do |i|
      ctx = TestContext.new( host, sp.default_options )
      ctx.with do
        changes = ctx.rput( 'd1/foo', "#{TEST_DIR}/d2/" )
        if i == 0
          assert_equal( %w[ foo ], changes.map { |c| c[1] } )
        else
          assert_empty( changes )
        end
        assert_equal( "barfoobar\n",
                      IO.read( "#{TEST_DIR}/d2/foo" ) )
      end
      assert_equal( 1, ctx.rsync_count )
    end
  end

  def test_rput_erb_suffix
    host = sp.host( 'localhost' )
    2.times do |i|
      ctx = TestContext.new( host, sp.default_options )
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
      assert_equal( 1, ctx.rsync_count )
    end
  end

  def test_rput_erb_rename
    host = sp.host( 'localhost' )
    2.times do |i|
      ctx = TestContext.new( host, sp.default_options )
      ctx.with do
        changes = ctx.rput( 'd1/foo.erb', "#{TEST_DIR}/baz" )
        if i == 0
          assert_equal( %w[ foo ], changes.map { |c| c[1] } )
          refute( File.exist?( "#{TEST_DIR}/foo" ) )
        else
          assert_empty( changes )
        end
        assert_equal( "barfoobar\n",
                      IO.read( "#{TEST_DIR}/baz" ) )
      end
      assert_equal( 1, ctx.rsync_count )
    end
  end

  def test_rput_missing_dir
    host = sp.host( 'localhost' )
    ctx = TestContext.new( host, sp.default_options )
    begin
      ctx.rput( 'nodir/', "#{TEST_DIR}/" )
      flunk "Expected SourceNotFound exception"
    rescue SourceNotFound => e
      refute_match( /.erb/, e.message )
      pass
    end
    assert_equal( 0, ctx.rsync_count )
  end

  def test_rput_missing_file
    host = sp.host( 'localhost' )
    ctx = TestContext.new( host, sp.default_options )
    begin
      ctx.rput( 'd1/goo', "#{TEST_DIR}/" )
      flunk "Expected SourceNotFound exception"
    rescue SourceNotFound => e
      refute_match( /.erb/, e.message )
      pass
    end
    assert_equal( 0, ctx.rsync_count )
  end

  def test_rput_contents_with_erb
    host = sp.host( 'localhost' )
    2.times do |i|
      ctx = TestContext.new( host, sp.default_options )
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
      assert_equal( 1, ctx.rsync_count )
    end
  end

  def test_rput_dir_with_erb
    host = sp.host( 'localhost' )
    2.times do |i|
      ctx = TestContext.new( host, sp.default_options )
      ctx.with do
        changes = ctx.rput( 'd1', "#{TEST_DIR}" )
        if i == 0
          assert_equal( %w[ d1/ d1/bar d1/foo ], changes.map { |c| c[1] } )
        else
          assert_empty( changes )
        end
        refute( File.executable?( "#{TEST_DIR}/d1/bar" ) )
        assert_equal( IO.read( "#{SYNC_DIR}/d1/bar" ),
                      IO.read( "#{TEST_DIR}/d1/bar" ) )
        refute( File.executable?( "#{TEST_DIR}/d1/foo" ) )
        assert_equal( "barfoobar\n",
                      IO.read( "#{TEST_DIR}/d1/foo" ) )
      end
      assert_equal( 1, ctx.rsync_count )
    end
  end

  def test_rput_subdir_with_erb
    host = sp.host( 'localhost' )
    2.times do |i|
      ctx = TestContext.new( host, sp.default_options )
      ctx.with do
        changes = ctx.rput( 'd3', "#{TEST_DIR}" )
        if i == 0
          assert_equal( %w[ d3/ d3/d2/ d3/d2/bar d3/d2/foo ],
                        changes.map { |c| c[1] } )
        else
          assert_empty( changes )
        end
        assert( File.executable?( "#{TEST_DIR}/d3/d2/bar" ) )
        assert_equal( IO.read( "#{SYNC_DIR}/d3/d2/bar" ),
                      IO.read( "#{TEST_DIR}/d3/d2/bar" ) )
        assert( File.executable?( "#{TEST_DIR}/d3/d2/foo" ) )
        assert_equal( "barfoobar\n",
                      IO.read( "#{TEST_DIR}/d3/d2/foo" ) )
      end
      assert_equal( 1, ctx.rsync_count )
    end
  end

  def test_rput_subdir_contents_with_erb
    host = sp.host( 'localhost' )
    2.times do |i|
      ctx = TestContext.new( host, sp.default_options )
      ctx.with do
        changes = ctx.rput( 'd3/', "#{TEST_DIR}" )
        if i == 0
          assert_equal( %w[ d2/ d2/bar d2/foo ], changes.map { |c| c[1] } )
        else
          assert_empty( changes )
        end
        assert( File.executable?( "#{TEST_DIR}/d2/bar" ) )
        assert_equal( IO.read( "#{SYNC_DIR}/d3/d2/bar" ),
                      IO.read( "#{TEST_DIR}/d2/bar" ) )
        assert( File.executable?( "#{TEST_DIR}/d2/foo" ) )
        assert_equal( "barfoobar\n",
                      IO.read( "#{TEST_DIR}/d2/foo" ) )
      end
      assert_equal( 1, ctx.rsync_count )
    end
  end

  def test_rput_erb_perm_change_only
    host = sp.host( 'localhost' )
    ctx = TestContext.new( host, sp.default_options )
    changes = ctx.rput( 'd3/', "#{TEST_DIR}" )
    assert_equal( %w[ d2/ d2/bar d2/foo ], changes.map { |c| c[1] } )
    assert( File.executable?( "#{TEST_DIR}/d2/foo" ) )
    assert_equal( 1, ctx.rsync_count )

    # Make the template target non-executable temporarily. On re-rput,
    # only change is that file should have its exec bits reset.
    ctx = TestContext.new( host, sp.default_options )
    FileUtils.chmod( 0664, "#{TEST_DIR}/d2/foo" )
    changes = ctx.rput( 'd3/', "#{TEST_DIR}" )
    assert_equal( [ %w[ .f...p..... d2/foo ] ], changes )
    assert( File.executable?( "#{TEST_DIR}/d2/foo" ) )
    assert_equal( 1, ctx.rsync_count )
  end

  def binding_under_test
    var = "foo"
    binding
  end

end
