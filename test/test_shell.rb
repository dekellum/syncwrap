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

require 'syncwrap/shell'

class TestShell < MiniTest::Unit::TestCase

  class Conch
    include SyncWrap::Shell
  end

  def test_capture_noop
    c = Conch.new
    exit_code, outputs = c.capture( %w[sh -c true])
    assert_equal( 0, exit_code )
    assert_equal( [], outputs )
  end

  def test_capture_error
    c = Conch.new
    exit_code, outputs = c.capture( %w[sh -v -c false])
    assert_equal( 1, exit_code )
    assert_equal( [[:err, "false\n"]], outputs, outputs )
  end

  def test_capture_output
    c = Conch.new
    exit_code, outputs = c.capture( %w[sh -v -c] << "echo foo")
    assert_equal( 0, exit_code )
    assert_equal( [ [:err, "echo foo\n"],
                    [:out, "foo\n"] ],
                  outputs, outputs )
  end

  def test_capture_multi_error
    c = Conch.new
    # Timing dependent, one or two reads will be received. Regardless,
    # capture should combine them to a single read as shown in output
    11.times do
      exit_code, outputs = c.capture( %w[sh -v -c] << "echo foo >&2")
      assert_equal( 0, exit_code )
      assert_equal( [[:err, "echo foo >&2\nfoo\n"]],
                    outputs, outputs )
    end
  end

end