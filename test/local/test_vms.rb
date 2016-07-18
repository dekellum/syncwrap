#!/usr/bin/env jruby
#.hashdot.profile += jruby-shortlived

#--
# Copyright (c) 2011-2016 David Kellum
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

# Test using the local sync.rb, and 'ubuntu-1' (12.04.4 LTS) and
# 'centos-1' (6.5) local VMs. This is not a default test.
# THE TEST CHANGES ARE POTENTIALLY DAMAGING. See sync.rb
class TestVMs < Minitest::Test
  include SyncWrap

  def setup
    @sp = Space.new
    @sp.load_sync_file_relative 'sync.rb'
  end

  # Uninstall, install, install-again
  def test_all
    puts "[[ Test execute Uninstaller.uninstall ]]"
    assert( @sp.execute( @sp.hosts, [ ['Uninstaller', :uninstall ]] ) )

    puts "[[ Test execute (from scratch) ]]"
    assert( @sp.execute )

    puts "[[ Test execute (over again) ]]"
    assert( @sp.execute )
  end

end
