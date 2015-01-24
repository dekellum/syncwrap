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
require 'syncwrap/distro'

module SyncWrap

  # \Arch Linux distro, partial implementation for pacman.
  class Arch < Component
    include SyncWrap::Distro

    def dist_install( *pkgs )
      opts = pkgs.last.is_a?( Hash ) && pkgs.pop || {}
      sudo "pacman -S --noconfirm #{pkgs.join ' '}"
    end

    def dist_uninstall( *pkgs )
      sudo "pacman -R --noconfirm #{pkgs.join ' '}"
    end

  end

end
