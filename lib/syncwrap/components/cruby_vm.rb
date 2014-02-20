#--
# Copyright (c) 2011-2014 David Kellum
#
# Licensed under the Apache License, Version 2.0 (the "License"); you
# may not use this file except in compliance with the License.  You may
# obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.  See the License for the specific language governing
# permissions and limitations under the License.
#++

require 'syncwrap/component'
require 'syncwrap/components/rhel'

module SyncWrap

  # Provision C Ruby (ruby-lang.org - Matz Ruby Interpreter or
  # MRI). Also includes utility methods for installing RubyGems.
  class CRubyVM < Component

    # Ruby version to install
    attr_accessor :ruby_version

    # The name of the gem command to be installed/used (default: gem)
    attr_accessor :gem_command

    # Default gem install arguments (default: --no-rdoc, --no-ri)
    attr_accessor :gem_install_args

    attr_accessor :do_uninstall_distro_ruby

    def initialize( opts = {} )
      @ruby_version = "2.0.0-p353"
      @gem_command = 'gem'
      @do_uninstall_distro_ruby = true #FIXME
      gem_install_args = %w[ --no-rdoc --no-ri ]

      super
    end

    def gemrc_path
      "/etc/gemrc"
    end

    def install
      install_ruby
      install_gemrc
    end

    # Install gemrc file to gemrc_path
    def install_gemrc
      rput( 'etc/gemrc', gemrc_path, user: :root )
    end

    def ruby_binary
      "#{local_root}/bin/ruby"
    end

    def compact_version
      ruby_version.sub( '-', '' )
    end

    def install_ruby
      cond = <<-SH
        rvr=`[ -x #{ruby_binary} ] \
             && #{ruby_binary} -v | grep -o -E '[0-9]+(\\.[0-9]+)+(p[0-9]+)?' \
             || true`
        if [ "$rvr" != "#{compact_version}" ]; then
      SH
      sudo( cond, close: "fi" ) do
        install_build_deps
        make_and_install
        uninstall_distro_ruby if do_uninstall_distro_ruby
      end
    end

    # Install the specified gem.
    #
    # ==== Options
    # :version:: Version specifier array, like in spec. files
    #            (default: none, i.e. latest)
    # :user_install:: If true, perform a --user-install as the current
    #                 user, else system install with sudo (the default)
    # :check:: If true, captures output and returns the number of gems
    #          actually installed.  Combine with :minimize to only
    #          install what is required, and short circuit when zero
    #          gems installed.
    # :minimize:: Use --conservative and --minimal-deps (rubygems
    #             2.1.5+) flags to reduce installs to the minimum
    #             required to satisfy the version requirments.
    def install_gem( gem, opts = {} )
      cmd = [ gem_command, 'install',
              gem_install_args,
              ( '--user-install' if opts[ :user_install ] ),
              ( '--conservative' if opts[ :minimize] != false ),
              ( '--minimal-deps' if opts[ :minimize] != false && min_deps_supported? ),
              gem_version_flags( opts[ :version ] ),
              gem ].flatten.compact.join( ' ' )

      shopts = opts[ :user_install ] ? {} : {user: :root}

      if opts[ :check ]
        _,out = capture( cmd, shopts.merge!( accept: 0 ) )

        count = 0
        out.split( "\n" ).each do |oline|
          if oline =~ /^\s+(\d+)\s+gem(s)?\s+installed/
            count = $1.to_i
          end
        end
        count
      else
        sh( cmd, shopts )
      end

      # FIXME: CommonRuby or some such module for above?
    end

    def uninstall_distro_ruby
      if distro.is_a?( RHEL )
        dist_uninstall( %w[ ruby ruby18 ruby19 ruby20 ] )
      else
        dist_uninstall( %w[ ruby ruby1.8 ruby1.9 ruby1.9.1 ruby1.9.3 ruby2.0 ] )
      end
    end

    protected

    def install_build_deps
      if distro.is_a?( RHEL )
        dist_install( %w[ gcc make autoconf zlib-devel
                          openssl-devel readline-devel libyaml-devel ] )
      else
        dist_install( %w[ gcc make autoconf zlib1g-dev
                          libssl-dev libreadline-dev libyaml-dev ] )
        # libreadline6-dev
      end
    end

    def make_and_install
      sudo <<-SH
        [ -e /tmp/src/ruby ] && rm -rf /tmp/src/ruby || true
        mkdir -p /tmp/src/ruby
        cd /tmp/src/ruby
        curl -sSL #{src_url} | tar -zxf -
        cd ruby-#{ruby_version}
        ./configure --prefix=#{local_root} #{redirect?}
        make #{redirect?}
        make install #{redirect?}
        cd / && rm -rf /tmp/src/ruby
      SH
    end

    def src_url
      [ 'http://cache.ruby-lang.org/pub/ruby',
        ruby_version =~ /^(\d+\.\d+)/ && $1,
        "ruby-#{ruby_version}.tar.gz" ].join( '/' )
    end

    def min_deps_supported?
      true
    end

    def gem_version_flags( reqs )
      Array( reqs ).flatten.compact.map { |req| "-v'#{req}'" }
    end

    def redirect?
      verbose? ? "" : ">/dev/null"
    end

  end

end
