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

require_relative '../setup'

require 'syncwrap'

# Extend the top level Object with the Main module in order to load
# local/sync.rb
self.extend SyncWrap::Main

# Test using the local sync.rb, and 'ubuntu-1' (12.04.4 LTS) and
# 'centos-1' (6.5) local VMs. This is not a default test.
# THE TEST CHANGES ARE POTENTIALLY DAMAGING.
class TestVMs < MiniTest::Unit::TestCase
  include SyncWrap

  LOCAL_DIR = File.dirname( __FILE__ )
  SYNC_DIR = File.join( LOCAL_DIR, 'sync' )

  def space
    Space.current
  end

  def setup
    Space.current = Space.new
    load File.join( LOCAL_DIR, 'sync.rb' )
  end

  # Uninstall, install, install-again
  def test
    skip unless TestOptions::LOCAL_VM_TEST
    puts "[[ Test execute Uninstaller.uninstall ]]"
    assert( space.execute( space.hosts, [ [ Uninstaller, :uninstall ] ] ) )

    puts "[[ Test execute (from scratch) ]]"
    assert( space.execute )

    puts "[[ Test execute (over again) ]]"
    assert( space.execute )
  end
end
