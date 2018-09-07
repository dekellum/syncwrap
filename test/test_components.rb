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

module SyncWrap

  class RpmUrlInstaller < Component
    def install
      dist_install( "http://foo.bar/goo-3.3.4.x86_64.rpm" )
    end
  end

  # Each of the following are default auto test construction plans,
  # for all components, used below.  The last component is under test
  # and run via #install if implemented.  The prior components are
  # known dependencies. A trailing Hash is used to populate required
  # or test-worthy component options. RHEL and Ubuntu are used
  # semi-randomly for <Distro> deps, or both are tested in the case of
  # non-trivial differentiation.
  AUTO_TESTS =
    [ [ RHEL, CommercialJDK ],
      [ Debian ],
      [ Debian, CRubyVM ],
      [ Debian, OpenJDK, JRubyVM, jruby_version: '9.1.12.0' ],
      [ CentOS, CRubyVM ],
      [ Arch, CRubyVM ],
      [ EtcHosts ],
      [ AmazonLinux, JRubyVM, RunUser, Iyyov, Geminabox ],
      [ AmazonLinux, { amazon_version: '2017.12' },
        JRubyVM, RunUser, Iyyov, Geminabox ],
      [ RHEL,   JRubyVM, BundlerGem ],
      [ RHEL,   CRubyVM, BundlerGem ],
      [ CentOS, JRubyVM, RakeGem ],
      [ RHEL,   CRubyVM, RakeGem ],
      [ RHEL,   RunUser, SourceTree,
        source_dir: 'lib', require_clean: false ],
      [ Debian, CRubyVM, BundlerGem, RunUser, Bundle,
        bundle_path: File.expand_path( '../../lib', __FILE__ ) ],
      [ AmazonLinux, RunUser, CRubyVM, BundlerGem,
        SourceTree, { source_dir: 'lib', require_clean: false },
        Bundle ],
      [ AmazonLinux, RunUser, CRubyVM, BundlerGem,
        SourceTree, { source_dir: 'lib', require_clean: false },
        ChangeGuard, { change_key: :source_tree } ],
      [ AmazonLinux, RunUser, CRubyVM, BundlerGem,
        SourceTree, { source_dir: 'lib', require_clean: false },
        ChangeGuard, { change_key: :source_tree },
        Bundle,
        ChangeUnGuard ],
      [ Ubuntu, RunUser, JRubyVM, BundlerGem, Iyyov,
        SourceTree, { source_dir: 'lib', require_clean: false },
        Bundle, BundledIyyovDaemon ],
      [ Ubuntu, RunUser, CRubyVM, BundlerGem, Puma,
        puma_version: '2.9.0', rack_path: File.expand_path( '../../lib', __FILE__ ) ],
      [ RHEL, RunUser, JRubyVM, BundlerGem,
        SourceTree, { source_dir: 'lib', require_clean: false },
        Bundle, Puma, systemd_unit: 'puma.service' ],
      [ RHEL, RunUser, JRubyVM, BundlerGem,
        SourceTree, { source_dir: 'lib', require_clean: false },
        Bundle, Puma, { systemd_service: 'puma.service',
                        systemd_socket: 'puma.socket',
                        puma_flags: { port: 5811 } } ],
      [ Debian, OpenJDK, JRubyVM, Hashdot ],
      [ RHEL,   JRubyVM, RunUser, Iyyov ],
      [ Ubuntu, JRubyVM, RunUser, Iyyov, IyyovDaemon, name: 'test', version: '0' ],
      [ CentOS, JRubyVM ],
      [ RHEL,   MDRaid, raw_devices: 1 ],
      [ Debian, MDRaid, raw_devices: 2 ],
      [ RHEL,   MDRaid, { raw_devices: 1, lvm_volumes: [ [1.0, '/tlv' ] ] },
        LVMCache, raw_device: '/dev/xvdb', lv_cache_target: 'tlv' ],
      [ Debian, MDRaid, { raw_devices: 2, lvm_volumes: [ [1.0, '/tlv' ] ] },
        LVMCache, raw_device: '/dev/xvdb', lv_cache_target: 'tlv' ],
      [ Debian, Network ],
      [ Ubuntu, Network ],
      [ RHEL,   Network ],
      [ RHEL, { rhel_version: '7' }, Network ],
      [ AmazonLinux, Network ],
      [ Debian, OpenJDK ],
      [ AmazonLinux, PostgreSQL ],
      [ Debian, PostgreSQL ],
      [ Ubuntu, PostgreSQL ],
      [ CentOS, PostgreSQL ],
      [ CentOS, PostgreSQL, pg_version: '10' ],
      [ RHEL, Qpid ],
      [ CentOS, QpidRepo, qpid_prebuild_repo: 'http://localhost' ],
      [ RHEL ],
      [ RHEL, RpmUrlInstaller ],
      [ RunUser ],
      [ RHEL,  CRubyVM, TarpitGem ],
      [ RHEL,  JRubyVM, TarpitGem ],
      [ RHEL, RunUser, JRubyVM, TarpitGem, user_install: true ],
      [ Debian, Rustc ],
      [ RHEL, Rustc ],
      [ Debian, Rustc,
        SourceTree, { source_dir: 'lib', remote_source_root: '/usr/local/src',
                      require_clean: false },
        Cargo ],
      [ Users, home_users: [ 'bob' ] ] ]

  # Test overrides to standard Context.
  class TestContext < Context
    include Shell
    attr_accessor :commands

    def initialize( *args )
      @commands = []
      super
    end

    # Run bash on localhost in dryrun mode (-n), for basic syntax
    # checking.
    def run_shell( command, opts = {} )
      opts = opts.merge( dryrun: true, coalesce: false, accept: [0] )
      args = sh_args( command, opts )
      capture_stream( args, host, :sh, opts )
      @commands << args
      nil
    end

    # Run bash on localhost in dryrun mode (-n), for basic syntax
    # checking. Return random selection of :accept return value and
    # empty output text.
    def capture_shell( command, opts = {} )
      accept = opts[ :accept ] || [ 0 ]
      opts = opts.merge( dryrun: true, coalesce: false, accept: [0] )
      args = sh_args( command, opts )
      capture_stream( args, host, :sh, opts )
      @commands << args
      [ accept[ rand( accept.length ) ], "" ]
    end

    # Don't run rsync. Return some or no changes at random.
    def rsync( srcs, target, opts )
      @commands << rsync_args( host, srcs, target, opts )
      ( rand(2) == 1 ) ? [ [ 'something', 'somefile' ] ] : []
    end

  end

  class TestComponents < Minitest::Test

    def with_test_context( sp, host )
      ctx = TestContext.new( host, sp.default_options )
      ctx.with do
        yield ctx
      end
    end

    AUTO_TESTS.each_with_index do |comps, i|
      comps = comps.dup
      comp_class_opts = comps.last.is_a?( Hash ) ? comps.pop : {}
      comp_class = comps.pop
      cname = ( comp_class.name =~ /([a-zA-Z0-9]+)$/ ) && $1.downcase

      define_method( "test_#{cname}_#{i}" ) do
        sp = Space.new
        host = sp.host( 'testhost' )
        until comps.empty? do
          dep_class = comps.shift
          dep_class_opts = comps.first.is_a?( Hash ) ? comps.shift : {}
          host.add( dep_class.new( dep_class_opts ) )
        end
        comp = comp_class.new( comp_class_opts )
        host.add( comp )
        pass
        if comp.respond_to?( :install )
          # Repeatedly test for randomized permutations
          3.times do
            with_test_context( sp, host ) do |ctx|
              comp.install
              ctx.flush
              assert_operator( ctx.commands.length, :>, 0 )
              # each command run is an effective assert
              ctx.commands.length.times { pass }
            end
          end
        end
      end

    end

  end

end
