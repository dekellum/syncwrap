#!/usr/bin/env jruby
#.hashdot.profile += jruby-shortlived

#--
# Copyright (c) 2011-2018 David Kellum
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
require 'syncwrap/rsync'

class TestRsync < Minitest::Test
  include SyncWrap::Rsync

  def test_expand_implied_target
    assert_expand( %w[ other/lang.sh /etc/],
                   %w[ other/lang.sh /etc/] )

    assert_expand( %w[ etc/profile.d/lang.sh /etc/profile.d/ ],
                   %w[ etc/profile.d/lang.sh ] )

    assert_expand( %w[ etc/profile.d/ /etc/profile.d/ ],
                   %w[ etc/profile.d/ ] )

    assert_expand( %w[ etc/profile.d /etc/ ],
                   %w[ etc/profile.d ] )
  end

  def test_user_options
    assert_opts( [ '--rsync-path=sudo rsync' ], user: 'root' )
    assert_opts( [ '--rsync-path=sudo rsync' ], user: :root )
    assert_opts( [ '--rsync-path=sudo -u runr rsync' ], user: 'runr' )
  end

  def test_exclude_options
    assert_opts( %w[ --cvs-exclude ], excludes: :dev )
    assert_opts( %w[ --cvs-exclude ], excludes: [ :dev ] )
    assert_opts( %w[ --exclude=foo ], excludes: 'foo' )
    assert_opts( %w[ --exclude=foo --exclude=bar ], excludes: %w[ foo bar ] )
  end

  def test_ssh_options
    assert_opts( [ '-e', 'ssh -l auser' ], ssh_user: 'auser' )
    assert_opts( [], ssh_user_pem: 'key.pem' )
    assert_opts( [ '-e', 'ssh -l auser -i key.pem' ],
                 ssh_user: 'auser', ssh_user_pem: 'key.pem' )
    assert_opts( [ '-e', 'ssh -o foo=bar' ], ssh_options: {'foo'=>'bar'} )
  end

  def test_other_options
    assert_opts( %w[ -n ], dryrun: true )
  end

  def test_localhost
    args = rsync_args( 'localhost', ['d'], 'd/' )
    assert_equal( %w[rsync -i -r -l -E -c -b d d/], args )
  end

  def assert_expand( expected, args )
    expanded = expand_implied_target( args )
    assert_equal( expected, expanded.flatten, expanded )
  end

  def assert_opts( expected, opts )
    args = rsync_args( 'testhost', ['d'], 'd/', opts )
    assert_equal( %w[rsync -i -r -l -E -c -b] +
                  expected +
                  %w[d testhost:d/],
                  args )
  end

  SYNC_DIR = File.join( SyncWrap::GEM_ROOT, 'sync' ).freeze
  SYNC_PATHS = [ SYNC_DIR ].freeze

  # Maintenance: We use gem's sync/src/hashdot template list for
  # testing, so expect breakage if that changes.
  SYNC_HASHDOT = ( SYNC_DIR + '/src/hashdot' ).freeze

  def test_relativize
    rel = relativize( SYNC_HASHDOT )
    assert_operator( rel, :!=, SYNC_HASHDOT )
    assert( File.identical?( SYNC_HASHDOT, rel ) )
    assert_equal( rel, relativize( rel ) )
    assert_equal( rel + '/', relativize( rel + '/' ) )
  end

  def test_subpath
    assert_equal( "",    subpath( "d/",     "d/f" ) )
    assert_equal( "",    subpath( "d",      "d/f" ) )
    assert_equal( "",    subpath( "d/e/",   "d/e/f" ) )
    assert_equal( "",    subpath( "d/e/d/", "d/e/d/f" ) )
    assert_equal( "e",   subpath( "d",      "d/e/f" ) )
    assert_equal( "e",   subpath( "d/e",    "d/e/f" ) )
    assert_equal( "e/d", subpath( "d",      "d/e/d/f" ) )
    assert_equal( "e/d", subpath( "d/",     "d/e/d/f" ) )
    assert_equal( "e/d", subpath( "d/e" ,   "d/e/d/f" ) )
    assert_equal( "d",   subpath( "d/e/",   "d/e/d/f" ) )
  end

  def test_resolve_sources
    src = resolve_source!( 'src/hashdot', SYNC_PATHS )
    assert( File.identical?( SYNC_HASHDOT, src ), src )
    assert( src[-1] != '/' )

    src = resolve_source!( 'src/hashdot/', SYNC_PATHS )
    assert( File.identical?( SYNC_HASHDOT, src ), src )
    assert( src[-1] == '/' )

    assert_raises( SyncWrap::SourceNotFound ) do
      resolve_sources( [ 'src/hashdot', 'not/found' ], SYNC_PATHS )
    end

    src = resolve_source!( 'src/hashdot', [ '/bogus' ] + SYNC_PATHS )
    assert( File.identical?( SYNC_HASHDOT, src ), src )
  end

  def test_find_source_erbs
    erbs = find_source_erbs( SYNC_HASHDOT ).sort
    assert_equal( [ SYNC_HASHDOT + '/Makefile.erb',
                    SYNC_HASHDOT + '/profiles/default.hdp.erb',
                    SYNC_HASHDOT + '/profiles/jruby.hdp.erb' ],
                  erbs )
  end

end
