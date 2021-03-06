#--
# Copyright (c) 2011-2018 David Kellum
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
require 'syncwrap/components/debian'
require 'syncwrap/components/rhel'
require 'syncwrap/ruby_support'
require 'syncwrap/version_support'
require 'syncwrap/hash_support'

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
  # for server provisioning because of their intrusive shell and
  # environment modifications and obscure interations with non-/login
  # or non-/interactive sessions. These are fine tools if needed for
  # development however. Again you are currently on your own (beyond
  # RubySupport) if you wish to go this route.
  class CRubyVM < Component
    include VersionSupport
    include RubySupport
    include HashSupport

    # Default #ruby_version to install
    DEFAULT_VERSION = '2.3.5'

    # A set of known (sha256) cryptographic hashes, keyed by version
    # string, for the source ruby-(version).tar.gz package.
    KNOWN_HASHES = %w[
      2.1.7  f59c1596ac39cc7e60126e7d3698c19f482f04060674fdfe0124e1752ba6dd81
      2.1.8  afd832b8d5ecb2e3e1477ec6a9408fdf9898ee73e4c5df17a2b2cb36bd1c355d
      2.1.10 fb2e454d7a5e5a39eb54db0ec666f53eeb6edc593d1d2b970ae4d150b831dd20
      2.2.5  30c4b31697a4ca4ea0c8db8ad30cf45e6690a0f09687e5d483c933c03ca335e3
      2.2.6  de8e192791cb157d610c48a9a9ff6e7f19d67ce86052feae62b82e3682cc675f
      2.2.7  374184c6c5bbc88fb7bad422368d4053a236fb6587f0eff76146dcba57f93da5
      2.2.8  8f37b9d8538bf8e50ad098db2a716ea49585ad1601bbd347ef84ca0662d9268a
      2.2.9  2f47c77054fc40ccfde22501425256d32c4fa0ccaf9554f0d699ed436beca1a6
      2.2.10 cd51019eb9d9c786d6cb178c37f6812d8a41d6914a1edaf0050c051c75d7c358
      2.3.3  241408c8c555b258846368830a06146e4849a1d58dcaf6b14a3b6a73058115b7
      2.3.4  98e18f17c933318d0e32fed3aea67e304f174d03170a38fd920c4fbe49fec0c3
      2.3.5  5462f7bbb28beff5da7441968471ed922f964db1abdce82b8860608acc23ddcc
      2.3.6  8322513279f9edfa612d445bc111a87894fac1128eaa539301cebfc0dd51571e
      2.3.7  35cd349cddf78e4a0640d28ec8c7e88a2ae0db51ebd8926cd232bb70db2c7d7f
      2.4.2  93b9e75e00b262bc4def6b26b7ae8717efc252c47154abb7392e54357e6c8c9c
      2.4.3  fd0375582c92045aa7d31854e724471fb469e11a4b08ff334d39052ccaaa3a98
      2.4.4  254f1c1a79e4cc814d1e7320bc5bdd995dc57e08727d30a767664619a9c8ae5a
      2.5.1  dac81822325b79c3ba9532b048c2123357d3310b2b40024202f360251d9829b1
    ].map(&:freeze).each_slice(2).to_h.freeze

    # The ruby version to install, as it appears in source packages
    # from ruby-lang.org. Note that starting with 2.1.0, the patch
    # release (p#) no longer appears in package names.
    # (Default: DEFAULT_VERSION)
    #
    # Example values: '2.0.0-p481', '2.2.8', '2.3.5', '2.4.2'
    attr_accessor :ruby_version

    # If true, attempt to uninstall any pre-existing distro packaged
    # ruby, which might otherwise lead to errors and confusion.
    # (Default: true)
    attr_accessor :do_uninstall_distro_ruby

    # A cryptographic hash value (hexadecimal, some standard length)
    # to use for verifying the 'source.tar.gz' package.
    # (Default: KNOWN_HASHES[ ruby_version ])
    attr_writer :hash

    def initialize( opts = {} )
      @ruby_version = DEFAULT_VERSION
      @do_uninstall_distro_ruby = true
      @hash = nil
      super
    end

    def hash
      @hash || KNOWN_HASHES[ ruby_version ]
    end

    def install
      install_ruby
      install_gemrc # from RubySupport
    end

    def ruby_command
      "#{local_root}/bin/ruby"
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
        dist_uninstall( %w[ ruby ruby18 ruby19
                            ruby20 ruby21 ruby22 ruby23 ruby24] )
      else
        dist_uninstall( %w[ ruby ruby1.8 ruby1.9 ruby1.9.1 ruby1.9.3
                            ruby2.0 ruby2.1 ruby2.2 ruby2.3 ruby2.4] )
      end
    end

    alias :cruby_gem_install :gem_install

    protected

    def compact_version
      ruby_version.sub( '-', '' )
    end

    def version_pattern
      if version_gte?( ruby_version, [2,1] )
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
        dist_install( %w[ curl gcc make autoconf zlib-devel
                          openssl-devel readline-devel libyaml-devel libffi-devel ] )
      else
        dist_install( %w[ curl gcc make autoconf ] )
        if distro.is_a?( Debian )
           dist_install( %w[ zlib1g-dev libssl-dev libreadline-dev
                             libyaml-dev libffi-dev ] )
           if version_lt?(ruby_version, [2,4]) && version_gte?(debian_version, [10])
             dist_install( %w[ libssl1.0-dev ] )
           end
        end
      end
    end

    def make_and_install
      # Arguably all but the final install should be run by an
      # unprivileged user. But its more likely merged this way, and if
      # "configure" or "make" can be exploited, so can "make install".
      sfile = File.basename( src_url )
      sudo <<-SH
        [ -e /tmp/src ] && rm -rf /tmp/src || true
        mkdir -p /tmp/src/ruby
        cd /tmp/src/ruby
        curl -sSL -o #{sfile} #{src_url}
      SH

      hash_verify( hash, sfile, user: :root ) if hash

      sudo <<-SH
        tar -zxf #{sfile}
        rm -f #{sfile}
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
