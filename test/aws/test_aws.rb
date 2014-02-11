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

# These tests require a working test setup, some of which is not
# checked in for security reasons, i.e. private/aws.json, key.pem,
# etc.
class TestAWSIntegration < MiniTest::Unit::TestCase
  include SyncWrap

  SYNC_FILE = File.expand_path( '../sync.rb', __FILE__ )

  def setup
    @sp = Space.new
    @sp.load_sync_file_relative SYNC_FILE
  end

  # Uninstall, install, install-again
  def test
    puts "[[ Create basic-test host ]]"
    @sp.provider.create_hosts( 1, :basic, 'basic-test', SYNC_FILE )

    puts "[[ Test execute ]]"
    assert( @sp.execute( [ @sp.host( 'basic-test' ) ] ) )

    puts "[[ Delete host ]]"
    @sp.provider.terminate_hosts( ['basic-test'], false, SYNC_FILE )
    pass
  end

end
