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

module SyncWrap

  # Each of the following are default auto test construction plans,
  # for all components, used below.  The last component is under test
  # and run via #install if implemented.  The prior components are
  # known dependencies. A trailing Hash is used to populate required
  # or test-worthy component options. RHEL and Ubuntu are used
  # semi-randomly for <Distro> dep.
  AUTO_TESTS =
    [ [ RHEL, CommercialJDK ],
      [ EtcHosts ],
      [ JRubyVM, RunUser, Iyyov, Geminabox ],
      [ Ubuntu, OpenJDK, JRubyVM, Hashdot ],
      [ RHEL, JRubyVM, RunUser, Iyyov ],
      [ JRubyVM, RunUser, Iyyov, IyyovDaemon, name: 'test', version: '0' ],
      [ RHEL, JRubyVM ],
      [ Ubuntu, MDRaid, raw_devices: 1 ],
      [ RHEL, Network ],
      [ Ubuntu, OpenJDK ],
      [ Ubuntu, PostgreSQL ],
      [ RHEL, Qpid ],
      [ RHEL, QpidRepo, qpid_prebuild_repo: 'http://localhost' ],
      [ RHEL ],
      [ RunUser ],
      [ Ubuntu ],
      [ Users ] ]

  class TestContext < Context
    attr_accessor :rsync_count

    def initialize( *args )
      @commands = []
      super
    end

    def capture_stream( *args )
      @commands << args
      [ 0, [] ]
    end
  end

  class TestComponents < MiniTest::Unit::TestCase

    def with_test_context( sp, host )
      ctx = TestContext.new( host, sp.default_options )
      ctx.with do
        yield ctx
      end
    end

    AUTO_TESTS.each do |comps|
      comps = comps.dup
      comp_class_opts = comps.last.is_a?( Hash ) ? comps.pop : {}
      comp_class = comps.pop
      cname = ( comp_class.name =~ /([a-zA-Z0-9]+)$/ ) && $1.downcase

      define_method( "test_#{cname}" ) do
        sp = Space.new
        host = sp.host( 'testhost' )
        comps.each do |dep|
          host.add( dep.new )
        end
        comp = comp_class.new( comp_class_opts )
        host.add( comp )
        pass
        if comp.respond_to?( :install )
          with_test_context( sp, host ) do | ctx|
            comp.install
          end
          pass
        end
      end

    end

  end

end
