#--
# Copyright (c) 2011-2015 David Kellum
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

# For distro class comparison only (pre-load for safety)
require 'syncwrap/components/debian'
require 'syncwrap/components/rhel'

module SyncWrap

  # Provision the {Hashdot}[http://hashdot.sourceforge.net/] JVM/script
  # launcher by building it with gcc on the target host.
  #
  # Host component dependencies: <Distro>, <JDK>, JRubyVM
  class Hashdot < Component

    # Hashdot version (default: 1.4.0)
    attr_accessor :hashdot_version

    def initialize( opts = {} )
      @hashdot_version = '1.4.0'

      super
    end

    def hashdot_bin_url
      [ 'http://downloads.sourceforge.net/project/hashdot/hashdot',
        hashdot_version,
        "hashdot-#{hashdot_version}-src.tar.gz" ].join( '/' )
    end

    # Install hashdot if the binary version doesn't match, otherwise
    # just update the profile config files.
    def install
      if !test_hashdot_binary
        install_system_deps
        install_hashdot
        changes = [ :installed ]
      else
        # Just update config as needed.
        changes = rput( 'src/hashdot/profiles/',
                        "#{local_root}/lib/hashdot/profiles/",
                        excludes: :dev, user: :root )
      end
      unless changes.empty?
        state[ :hashdot_updated ] = changes
      end
      changes
    end

    def install_system_deps
      deps = %w[ make gcc ]
      deps += case distro
              when Debian
                %w[ libapr1 libapr1-dev ]
              when RHEL
                %w[ apr apr-devel ]
              else
                %w[ apr ]
              end
      dist_install( *deps )
    end

    def test_hashdot_binary
      binary = "#{local_root}/bin/hashdot"
      code,_ = capture( <<-SH, accept: [0,91,92] )
        if [ -x #{binary} ]; then
          cver=`(#{binary} 2>&1 || true) | grep -o -E '([0-9]\.?){2,}'`
          if [ "$cver" = "#{hashdot_version}" ]; then
            exit 0
          fi
          exit 92
        fi
        exit 91
      SH
      (code == 0)
    end

    def install_hashdot
      src_root = '/tmp/src/hashdot'
      src = "#{src_root}/hashdot-#{hashdot_version}"

      sh <<-SH
        sudo rm -rf /tmp/src
        mkdir -p #{src_root}
        curl -sSL #{hashdot_bin_url} | tar -C #{src_root} -zxf -
      SH

      rput( 'src/hashdot/', "#{src}/", :excludes => :dev )

      sh <<-SH
        cd #{src}
        make
        sudo make install
      SH

    end

  end

end
