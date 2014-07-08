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
require 'syncwrap/ruby_support'

module SyncWrap

  # Provision 'C' Ruby (ruby-lang.org - Matz Ruby Interpreter, MRI)
  # from source code, compiled on the target host.  This is currently
  # the most reliable way for staying up-to-date on stable Ruby
  # releases across the bulk of Linux server distros (which have
  # conservative update policies).
  #
  # A reasonable alternative is to use distro provided packages. Since
  # this varies so much based on distro particulars, but it is
  # otherwise relatively easy to achieve (setup alt repos,
  # dist_install, set alternatives) you are currently left to do this
  # in your own component. Include RubySupport in that component for
  # some common utility methods.
  #
  # Alternatives like RVM, rbenv, etc. are disfavored by this author
  # for server provisioning because of their often arcane shell and
  # environment modifications and obscure interations with non-/login
  # or non-/interactive sessions. These are fine tools if needed for
  # development however. Again you are currently on your own (beyond
  # RubySupport) if you wish to go this route.
  class CRubyVM < Component
    include RubySupport

    # The ruby version to install, as it appears in source packages
    # from ruby-lang.org. Note that starting with 2.1.0, the patch
    # release (p#) no longer appears in package names.
    # (Default: 2.0.0-p451)
    #
    # Example values: '2.0.0-p451', '2.1.2'
    attr_accessor :ruby_version

    # If true, attempt to uninstall any pre-existing distro packaged
    # ruby, which might otherwise lead to errors and confusion.
    # (Default: true)
    attr_accessor :do_uninstall_distro_ruby

    def initialize( opts = {} )
      @ruby_version = "2.0.0-p451"
      @do_uninstall_distro_ruby = true

      super
    end

    def install
      install_ruby
      install_gemrc # from RubySupport
    end

    def ruby_command
      "#{local_root}/bin/ruby"
    end

    # Return ruby_version as an array of Integer values
    def ruby_version_a
      ruby_version.split( /[.\-p]+/ ).map( &:to_i )
    end

    # If the current ruby_command is not at the desired ruby_version,
    # download source, configure, make and install.
    def install_ruby
      cond = <<-SH
        rvr=`[ -x #{ruby_command} ] &&
             #{ruby_command} -v | grep -o -E '#{version_pattern}' \
             || true`
        if [ "$rvr" != "#{compact_version}" ]; then
      SH
      sudo( cond, close: "fi" ) do
        install_build_deps
        make_and_install

        # only after a successful source install:
        uninstall_distro_ruby if do_uninstall_distro_ruby
      end
    end

    def uninstall_distro_ruby
      if distro.is_a?( RHEL )
        dist_uninstall( %w[ ruby ruby18 ruby19 ruby20 ] )
      else
        dist_uninstall( %w[ ruby ruby1.8 ruby1.9 ruby1.9.1 ruby1.9.3 ruby2.0 ] )
      end
    end

    alias :cruby_gem_install :gem_install

    protected

    def compact_version
      ruby_version.sub( '-', '' )
    end

    def version_pattern
      if ( ruby_version_a <=> [2,1] ) > 0
        # Starting with 2.1.x, the p# (patch number) is no longer used
        # for download, won't be in ruby_version, and shouldn't be
        # used for version comparison.
        '[0-9]+(\.[0-9]+)+'
      else
        '[0-9]+(\.[0-9]+)+(p[0-9]+)?'
      end
    end

    def install_build_deps
      if distro.is_a?( RHEL )
        dist_install( %w[ gcc make autoconf zlib-devel
                          openssl-devel readline-devel libyaml-devel ] )
      else
        dist_install( %w[ gcc make autoconf zlib1g-dev
                          libssl-dev libreadline-dev libyaml-dev ] )
      end
    end

    def make_and_install
      # Arguably all but the final install should be run by an
      # unprivileged user. But its more likely merged this way, and if
      # "configure" or "make" can be exploited, so can "make install".
      sudo <<-SH
        [ -e /tmp/src ] && rm -rf /tmp/src || true
        mkdir -p /tmp/src/ruby
        cd /tmp/src/ruby
        curl -sSL #{src_url} | tar -zxf -
        cd ruby-#{ruby_version}
        ./configure --prefix=#{local_root} #{redirect?}
        make #{redirect?}
        make install #{redirect?}
        cd / && rm -rf /tmp/src
      SH
    end

    def src_url
      [ 'http://cache.ruby-lang.org/pub/ruby',
        ruby_version =~ /^(\d+\.\d+)/ && $1,
        "ruby-#{ruby_version}.tar.gz" ].join( '/' )
    end

    def redirect?
      verbose? ? "" : ">/dev/null"
    end

  end

end
