#--
# Copyright (c) 2018 David Kellum
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
require 'syncwrap/version_support'
require 'syncwrap/hash_support'

module SyncWrap

  # Provision `rustc`, and other build tools like `cargo`, using a "standalone
  # installer" (pre-built binary tarball), which is keyed by a version and
  # various platform designators.
  #
  # See: https://www.rust-lang.org/en-US/other-installers.html#standalone
  # Host component dependencies: <Distro>
  class Rustc < Component
    include VersionSupport
    include HashSupport

    DEFAULT_VERSION = "1.27.2"

    # The rustc version being installed.
    # (Default: DEFAULT_VERSION)
    #
    # Example values: '1.27.2'
    attr_accessor :rustc_version

    # A set of known (sha256) cryptographic hashes, keyed by version
    # string, for the standalone installer binary xz file.
    KNOWN_HASHES = %w[
      1.27.2 090a3bfc536b7211ae84f6667c941c861eddfdcadb5e472a32e72d074f793dd4
    ].map(&:freeze).each_slice(2).to_h.freeze

    # A cryptographic hash value (hexadecimal, some standard length)
    # to use for verifying the installer tarball.
    # (Default: KNOWN_HASHES[ rustc_version ])
    attr_writer :hash

    # The Rust-style platform designator.
    # (Default: 'x86_64-unknown-linux-gnu')
    attr_accessor :platform

    # If true, attempt to uninstall any pre-existing distro packaged
    # rust, which might otherwise lead to errors and confusion.
    # (Default: true)
    attr_accessor :do_uninstall_distro_rust

    def initialize( opts = {} )
      @rustc_version = DEFAULT_VERSION
      @hash = nil
      @do_uninstall_distro_rust = true
      @platform = 'x86_64-unknown-linux-gnu'
      super
    end

    def hash
      @hash || KNOWN_HASHES[ rustc_version ]
    end

    def install
      cond = <<-SH
        rvr=`[ -x #{rustc_command} ] &&
             #{rustc_command} -V | grep -o -E '[0-9]+(\\.[0-9]+)+' \
             || true`
        if [ "$rvr" != "#{rustc_version}" ]; then
      SH
      sudo( cond, close: "fi" ) do
        install_deps
        download_and_install

        # only after a successful source install:
        uninstall_distro_rust if do_uninstall_distro_rust
      end

    end

    def install_deps
      if distro.is_a?( Debian )
        dist_install( %w[ xz-utils pkg-config] )
      else
        dist_install( %w[ xz pkg-config] )
      end
    end

    def download_and_install
      ifile = File.basename( installer_url )
      sudo <<-SH
        [ -e /tmp/src ] && rm -rf /tmp/src || true
        mkdir -p /tmp/src/rust
        cd /tmp/src/rust
        curl -sSL -o #{ifile} #{installer_url}
      SH

      hash_verify( hash, ifile, user: :root ) if hash

      # FIXME: Use something other than ./install.sh for non-linux platforms?
      sudo <<-SH
        tar -Jxf #{ifile}
        rm -f #{ifile}
        cd rust-#{rustc_version}-#{platform}
        bash ./install.sh
        cd / && rm -rf /tmp/src
      SH
    end

    def uninstall_distro_rust
      # FIXME: For RHEL?
      dist_uninstall( %w[ rust rustc rustup cargo ] )
    end

    # Installed path to the `rustc` command
    def rustc_command
      "#{local_root}/bin/rustc"
    end

    protected

    # The URL to the installer tarball (xz compressed)
    def installer_url
      [ 'https://static.rust-lang.org/dist',
        "rust-#{rustc_version}-#{platform}.tar.xz"
      ].join( '/' )
    end

  end

end
