#--
# Copyright (c) 2011-2013 David Kellum
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

module SyncWrap

  # Provision the {Hashdot}[http://hashdot.sourceforge.net/] JVM/script
  # launcher by building it with gcc on the target host.
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
      else
        # Just update config as needed.
        # FIXME: Should be templates here
        rput( 'src/hashdot/profiles/',
              "#{local_root}/lib/hashdot/profiles/",
              :excludes => :dev, :user => 'root' )
      end
    end

    def install_system_deps
      dist_install( %w[ make gcc apr apr-devel ] )
    end

    def test_hashdot_binary
      binary = "#{local_root}/bin/hashdot"
      code,_ = capture( <<-SH, accept: [0,91,92] )
        if [ -x #{binary} ]; then
          cver="$(#{binary} 2>&1 | grep -o -E '([0-9]\.?){2,}')"
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

      sudo "rm -rf #{src_root}"

      sh <<-SH
        mkdir -p #{src_root}
        curl -sSL #{hashdot_bin_url} | tar -C #{src_root} -zxf -
      SH

      # FIXME: Should be templates here
      rput( 'src/hashdot/', "#{src}/", :excludes => :dev )
      sh "cd #{src} && make"
      sudo "cd #{src} && make install"
    end

  end

end
