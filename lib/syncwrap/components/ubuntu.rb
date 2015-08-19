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

require 'syncwrap/components/debian'

module SyncWrap

  # Customizations for \Ubuntu and derivatives. Specific
  # distros/versions may further specialize.
  class Ubuntu < Debian

    # Ubuntu version, i.e. '14.04' or '12.04.4'. No default value.
    attr_accessor :ubuntu_version

    alias :distro_version :ubuntu_version

    # Return Debian#debian_version if specified, or provide comparable
    # default Debian version if #ubuntu_vesion is specified. This is
    # an approximation of the LTS lineage.
    def debian_version
      super ||
        ( version_gte?( ubuntu_version, [15,4] ) && '8' ) ||
        ( version_gte?( ubuntu_version, [14,4] ) && '7' ) ||
        ( version_gte?( ubuntu_version, [12,4] ) && '6' )
    end

  end

end
