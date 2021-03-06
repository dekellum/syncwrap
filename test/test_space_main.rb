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
require 'syncwrap/version_support.rb'

class SyncWrap::IyyovDaemon
  public :daemon_service_dir
end

class TestSpaceMain < Minitest::Test
  include SyncWrap
  include VersionSupport

  def setup
    @sp = Space.new
    @sp.load_sync_file_relative( 'muddled_sync.rb' )
    f = @sp.formatter
    def f.write_component( *args )
      #disable
    end
  end

  def test_wrap
    skip if ( defined?( JRUBY_VERSION ) &&
              ( version_lt?( JRUBY_VERSION, [1,7,24] ) ||
                ( version_gte?( JRUBY_VERSION, [9] ) &&
                  version_lt?(  JRUBY_VERSION, [9,0,5] ) ) ) )
    # JRuby 1.6.x, 1.7.[0-23], 9.0.[0-4] all fail this test
    # See also Space#wrap_sync_load?
    assert( @sp.execute( @sp.hosts, [ [IyyovDaemon, :daemon_service_dir] ] ) )
  end
end
