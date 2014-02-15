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
  # Qpid AMQP broker provisioning. Currently this is RHEL/AmazonLinux
  # centric.
  class Qpid < Component

    attr_accessor :qpid_src_root

    attr_accessor :qpid_version
    attr_accessor :qpid_repo
    attr_accessor :qpid_distro

    attr_accessor :corosync_version
    attr_accessor :corosync_repo

    def initialize( opt = {} )
      @qpid_src_root = '/tmp/src'

      @qpid_version = '0.24'
      @qpid_repo = 'http://archive.us.apache.org/dist/qpid'
      # FIXME: Usable only for the newest builds
      # @qpid_repo = 'http://apache.osuosl.org/qpid'
      @qpid_distro = 'amzn1'

      @corosync_version = '1.4.4'
      @corosync_repo = 'http://corosync.org/download'

      super
    end

    def install
      unless distro.kind_of?( RHEL )
        raise ContextError, "#{distro.class} unsupported"
      end
      qpid_install
    end

    def qpid_install
      unless test_qpidd_version
        qpid_install!
        qpid_install_init!
      end
      qpid_tools_install
      rput( 'usr/local/etc/qpidd.conf', user: :root )
    end

    def test_qpidd_version
      bin = "/usr/local/sbin/qpidd"
      code,_ = capture( <<-SH, accept:[0,91,92] )
        if [ -x #{bin} ]; then
          ver=`#{bin} --version | grep -o -E '[0-9]+(\.[0-9]+)+$'`
          if [ "$ver" = "#{qpid_version}" ]; then
             exit 0
          fi
          exit 92
        fi
        exit 91
      SH
      (code == 0)
    end

    def qpid_install_init!
      sudo <<-SH
        if ! id qpidd >/dev/null 2>&1; then
          useradd -r qpidd
        fi
        mkdir -p /var/local/qpidd
        chown qpidd:qpidd /var/local/qpidd
      SH

      rput( 'etc/init.d/qpidd', user: :root )

      # Add to init.d
      dist_install_init_service( 'qpidd' )
    end

    def qpid_tools_install
      unless exist?( "/usr/bin/qpid-config" )
        qpid_tools_install!
      end
    end

    def qpid_install!
      corosync_install!( devel: true )
      qpid_build
    end

    def corosync_install( opts = {} )
      unless exist?( "/usr/sbin/corosync" )
        corosync_install!( opts )
      end
    end

    def corosync_install!( opts = {} )
      corosync_build
      dist_install( "#{corosync_src}/x86_64/*.rpm", succeed: true )
    end

    def qpid_tools_install!
      dist_install( 'python-setuptools' )
      qpid_src = "#{qpid_src_root}/qpid-#{qpid_version}"

      sh <<-SH
        mkdir -p #{qpid_src_root}
        rm -rf #{qpid_src}
        cd #{qpid_src_root}
        curl -sSL #{qpid_tools_tarball} | tar -zxf -
      SH

      sudo <<-SH
        cd #{qpid_src}
        easy_install ./python ./tools ./extras/qmf
      SH
    end

    protected

    def qpid_build
      qpid_install_build_deps
      qpid_install_deps

      qpid_src = "#{qpid_src_root}/qpidc-#{qpid_version}"

      sh <<-SH
        mkdir -p #{qpid_src_root}
        rm -rf #{qpid_src}
        cd #{qpid_src_root}
        curl -sSL #{qpid_src_tarball} | tar -zxf -
        cd #{qpid_src}
        ./configure --enable-deprecated-autotools #{redirect?}
        make #{redirect?}
      SH

      sudo <<-SH
        cd #{qpid_src}
        make install #{redirect?}
        make check #{redirect?}
        cd /usr/local
        rm -f /tmp/qpidc-#{qpid_version}-1-#{qpid_distro}-x64.tar.gz
        tar -zc \
             --exclude games --exclude lib64/perl5 --exclude src \
             --exclude share/man --exclude share/perl5 --exclude share/info \
             --exclude share/applications \
             -f /tmp/qpidc-#{qpid_version}-1-#{qpid_distro}-x64.tar.gz .
      SH
    end

    def qpid_src_tarball
      "#{qpid_repo}/#{qpid_version}/qpid-cpp-#{qpid_version}.tar.gz"
    end

    def qpid_tools_tarball
      "#{qpid_repo}/#{qpid_version}/qpid-#{qpid_version}.tar.gz"
    end

    def qpid_install_build_deps
      dist_install( %w[ gcc gcc-c++ make autogen autoconf
                        help2man libtool pkgconfig rpm-build ] )
    end

    def qpid_install_deps
      dist_install( %w[ nss-devel boost-devel libuuid-devel swig
                        ruby-devel python-devel
                        cyrus-sasl-devel cyrus-sasl-plain cyrus-sasl-md5 ] )
    end

    def corosync_build
      qpid_install_build_deps
      corosync_install_build_deps

      sh <<-SH
        mkdir -p #{qpid_src_root}
        rm -rf #{corosync_src}
        cd #{qpid_src_root}
        curl -sSL #{corosync_repo}/corosync-#{corosync_version}.tar.gz | tar -zxf -
        cd #{corosync_src}
        ./autogen.sh #{redirect?}
        ./configure #{redirect?}
        make rpm #{redirect?}
      SH

    end

    def corosync_packages( include_devel = false )
      packs = [ "corosync-#{corosync_version}-1.#{qpid_distro}.x86_64.rpm",
                "corosynclib-#{corosync_version}-1.#{qpid_distro}.x86_64.rpm" ]
      packs <<  "corosynclib-devel-#{corosync_version}-1.#{qpid_distro}.x86_64.rpm" if include_devel
      packs
    end

    def corosync_install_build_deps
      dist_install( %w[ nss-devel libibverbs-devel librdmacm-devel ] )
    end

    def corosync_src
      "#{qpid_src_root}/corosync-#{corosync_version}"
    end

    def exist?( file )
      code,_ = capture( "test -e #{file}", accept:[0,1] )
      (code == 0)
    end

    def redirect?
      verbose? ? "" : ">/dev/null"
    end

  end

  # Simplify qpid install by using pre-built binaries (for example,
  # archived from the build in Qpid)
  class QpidRepo < Qpid

    attr_accessor :qpid_prebuild_repo

    def initialize( opt = {} )
      @qpid_prebuild_repo = nil
      super
      raise "qpid_prebuild_repo required, but not set" unless qpid_prebuild_repo
    end

    def qpid_install
      corosync_install
      super
    end

    def qpid_install!

      dist_install( %w[ boost cyrus-sasl ] )

      sudo <<-SH
       cd /usr/local
       curl -sS #{qpid_prebuild_repo}/qpidc-#{qpid_version}-1-#{qpid_distro}-x64.tar.gz | tar -zxf -
      SH
    end

    def corosync_install!( opts = {} )
      packs = corosync_packages
      curls = packs.map do |p|
        "curl -sS -O #{qpid_prebuild_repo}/#{p}"
      end

      sudo <<-SH
        rm -rf /tmp/rpm-drop
        mkdir -p /tmp/rpm-drop
        cd /tmp/rpm-drop
        #{curls.join("\n")}
      SH
      dist_install( "/tmp/rpm-drop/*.rpm", succeed: true )
    end

    protected

    # Where uploaded qpid-python-tools-M.N.tar.gz contains the
    # ./python ./tools ./extras/qmf packages for easy_install.
    def qpid_tools_tarball
      "#{qpid_prebuild_repo}/qpid-python-tools-#{qpid_version}.tar.gz"
    end

  end

end
