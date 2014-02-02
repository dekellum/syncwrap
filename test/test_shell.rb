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

require 'syncwrap/shell'

class TestShell < MiniTest::Unit::TestCase
  include TestOptions
  include SyncWrap::Shell

  def test_command_lines_cleanup
    cmd = command_lines_cleanup( [ "", "  a\nb", "\n c\n", "d m n \n \n" ] )
    assert_equal( (%w[a b c] << "d m n").join( "\n" ), cmd )

    cmd = <<-SH
      if true; then

        echo yep
      else
        echo huh
      fi
    SH

    expected = [ "if true; then",
                 "  echo yep",
                 "else",
                 "  echo huh",
                 "fi" ].join( "\n" )

    assert_equal( expected, command_lines_cleanup( cmd ) )
    assert_equal( expected, command_lines_cleanup( expected ) )
  end

  def test_capture_noop
    exit_code, outputs = capture3( %w[sh -c true])
    assert_equal( 0, exit_code )
    assert_equal( [], outputs )
  end

  def test_capture_error
    exit_code, outputs = capture3( %w[sh -v -c] << "exit 33" )
    assert_equal( 33, exit_code )
    assert_equal( [[:err, "exit 33\n"]], outputs, outputs )
  end

  def test_capture_output
    exit_code, outputs = capture3( %w[sh -v -c] << "echo foo" )
    assert_equal( 0, exit_code )
    assert_equal( [ [:err, "echo foo\n"],
                    [:out, "foo\n"] ],
                  outputs.sort ) #order uncertain
  end

  def test_capture_output_interleaved
    exit_code, outputs = capture3( sh_args( <<-'SH', sh_verbose: :v ))
      echo foo
      echo bar
    SH
    assert_equal( 0, exit_code )
    assert_equal( "echo foo\necho bar\n",
                  collect_stream( :err, outputs ) )
    assert_equal( "foo\nbar\n",
                  collect_stream( :out, outputs ) )
  end

  def test_capture_output_coalesce
    cmd = sh_args( <<-'SH', sh_verbose: :v, coalesce: true )
      echo foo
      echo bar
    SH
    unmerged = []
    exit_code, merged = capture3( cmd ) do |stream, chunk|
      unmerged << [ stream, chunk ]
    end
    assert_equal( 0, exit_code )
    assert_equal( [[:err, "echo foo\nfoo\necho bar\nbar\n"]],
                  merged, merged )
    post_merged = unmerged.map {|s,c| c}.inject( "", :+ )
    assert_equal( merged[0][1], post_merged )
  end

  def test_capture_multi_error
    # Timing dependent, one or two reads will be received. Regardless,
    # capture3 should combine them to a single read as shown
    11.times do
      exit_code, outputs = capture3( %w[sh -v -c] << "echo foo >&2")
      assert_equal( 0, exit_code )
      assert_equal( [[:err, "echo foo >&2\nfoo\n"]],
                    outputs, outputs )
    end
  end

  def test_shell_special_chars
    exit_code, outputs = capture3( sh_args( <<-'SH' ) )
      var=33
      echo \# "!var" "\"$var\"" "\$" "#"
      echo \$ '!var' '"$var"' '$' '#'
    SH
    assert_equal( 0, exit_code )
    assert_equal( [[:out, ( "# !var \"33\" $ #\n" +
                            "$ !var \"$var\" $ #\n" )]],
                  outputs, outputs )
  end

  def test_sudo
    skip unless SAFE_SUDO
    cmd = sudo_args( 'echo foo', user: :root )
    exit_code, outputs = capture3( cmd )
    assert_equal( 0, exit_code )
    assert_equal( [[:out, "foo\n"]], outputs, outputs )
  end

  def test_ssh
    skip unless SAFE_SSH
    cmd = ssh_args( SAFE_SSH, 'echo foo', sh_verbose: :v )
    exit_code, outputs = capture3( cmd )
    assert_equal( 0, exit_code )
    # Timing dependend order:
    assert_equal( [ [:err, "echo foo\n"],
                    [:out, "foo\n"] ],
                  outputs.sort ) #order uncertain
  end

  def test_ssh_coalesce
    skip unless SAFE_SSH
    cmd = ssh_args( SAFE_SSH, <<-'SH', sh_verbose: :v, coalesce: true )
      echo foo
      echo bar
    SH
    unmerged = []
    exit_code, merged = capture3( cmd ) do |stream, chunk|
      unmerged << [ stream, chunk ]
    end
    assert_equal( 0, exit_code )
    assert_equal( [[:err, "echo foo\nfoo\necho bar\nbar\n"]],
                  merged, merged )
    post_merged = unmerged.map {|s,c| c}.inject( "", :+ )
    assert_equal( merged[0][1], post_merged )
  end

  def test_ssh_sudo
    skip unless SAFE_SSH && SAFE_SSH_SUDO
    cmd = ssh_args( SAFE_SSH, 'echo foo', sh_verbose: :v, user: :root )
    exit_code, outputs = capture3( cmd )
    assert_equal( 0, exit_code )
    assert_equal( [ [:err, "echo foo\n"],
                    [:out, "foo\n" ] ],
                  outputs.sort ) #order uncertain
  end

  def test_ssh_sudo_coalesce
    skip unless SAFE_SSH && SAFE_SSH_SUDO
    cmd = ssh_args( SAFE_SSH, <<-'SH', sh_verbose: :v, coalesce: true, user: :root )
      echo foo
      echo bar
    SH
    unmerged = []
    exit_code, merged = capture3( cmd ) do |stream, chunk|
      unmerged << [ stream, chunk ]
    end
    assert_equal( 0, exit_code )
    assert_equal( [[:err, "echo foo\nfoo\necho bar\nbar\n"]],
                  merged, merged )
    post_merged = unmerged.map {|s,c| c}.inject( "", :+ )
    assert_equal( merged[0][1], post_merged )
  end

  def test_ssh_sudo_escape
    skip unless SAFE_SSH && SAFE_SSH_SUDO
    cmd = ssh_args( SAFE_SSH, <<-'SH', user: :root )
      var=33
      echo \# "!var" "\"$var\"" "\$" "#"
      echo \$ '!var' '"$var"' '$' '#'
    SH
    exit_code, outputs = capture3( cmd )
    assert_equal( 0, exit_code )
    assert_equal( [[:out, ( "# !var \"33\" $ #\n" +
                            "$ !var \"$var\" $ #\n" )]],
                  outputs, outputs )
  end

end
