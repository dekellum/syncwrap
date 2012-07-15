#--
# Copyright (c) 2011-2012 David Kellum
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

require 'syncwrap/common'
require 'syncwrap/distro'

# Provisions the {Hashdot}[http://hashdot.sourceforge.net/] JVM/script
# launcher by building it with gcc on the target host.
module SyncWrap::Hashdot
  include SyncWrap::Common
  include SyncWrap::Distro

  # Hashdot version (default: 1.4.0)
  attr_accessor :hashdot_version

  def initialize
    super

    @hashdot_version = '1.4.0'
  end

  def hashdot_install_system_deps
    dist_install( %w[ make gcc apr apr-devel ] )
  end

  # Install hashdot if the binary is not found. If the binary is found
  # then still attempt to update the profile config files.
  def hashdot_install
    if !exist?( "#{common_prefix}/bin/hashdot" )
      hashdot_install!
    else
      # Just update config as needed.
      rput( 'src/hashdot/profiles/',
            "#{common_prefix}/lib/hashdot/profiles/",
            :excludes => :dev, :user => 'root' )
    end
  end

  def hashdot_install!
    hashdot_install_system_deps

    url = ( "http://downloads.sourceforge.net/project/hashdot/" +
            "hashdot/#{hashdot_version}/hashdot-#{hashdot_version}-src.tar.gz" )
    src_root = '/tmp/src'
    hd_src = "#{src_root}/hashdot-#{hashdot_version}"

    run <<-SH
      mkdir -p #{src_root}
      rm -rf #{hd_src}
      curl -sSL #{url} | tar -C #{src_root} -zxf -
    SH
    rput( 'src/hashdot/', "#{hd_src}/", :excludes => :dev )
    run  "cd #{hd_src} && make"
    sudo "cd #{hd_src} && make install"
  end

end
