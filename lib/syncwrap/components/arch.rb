#--
# Copyright (c) 2011-2017 David Kellum
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
require 'syncwrap/distro'
require 'syncwrap/systemd'

module SyncWrap

  # \Arch Linux distro, partial implementation for pacman.
  class Arch < Component
    include Distro
    include SystemD

    def systemd?
      true
    end

    # Install the specified package names. A trailing hash is
    # interpreted as options, see below.
    #
    # ==== Options
    #
    # :check_install:: Short-circuit if all packages already
    #                  installed. Thus no upgrades will be
    #                  performed. (Default: true)
    #
    # Options are also passed to the sudo calls.
    def dist_install( *pkgs )
      opts = pkgs.last.is_a?( Hash ) && pkgs.pop || {}
      pkgs.flatten!
      chk = opts[ :check_install ]
      chk = check_install? if chk.nil?
      dist_if_not_installed?( pkgs, chk != false, opts ) do
        sudo( "pacman -S --noconfirm #{pkgs.join ' '}", opts )
      end
    end

    # Uninstall the specified package names. A trailing hash is
    # interpreted as options and passed to the sudo calls.
    def dist_uninstall( *pkgs )
      opts = pkgs.last.is_a?( Hash ) && pkgs.pop || {}
      pkgs.flatten!
      pkgs.each do |pkg|
        dist_if_installed?( pkg, opts ) do
          sudo( "pacman -R --noconfirm #{pkg}", opts )
        end
      end
    end

    # If chk is true, then wrap block in a sudo bash conditional
    # testing if any specified pkgs are not installed. Otherwise just
    # yield to block.
    def dist_if_not_installed?( pkgs, chk = true, opts = {}, &block )
      if chk
        sudo_if( "! pacman -Q #{pkgs.join ' '} >/dev/null 2>&1", opts, &block )
      else
        block.call
      end
    end

    # Wrap block in a sudo bash conditional testing if the single
    # specified pkg is installed.
    def dist_if_installed?( pkg, opts = {}, &block )
      sudo_if( "pacman -Q #{pkg} >/dev/null 2>&1", opts, &block )
    end

    alias_method :dist_service, :dist_service_via_systemctl

  end

end
