#--
# Copyright (c) 2011-2016 David Kellum
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

require 'syncwrap/components/rhel'

module SyncWrap

  # Customizations for Amazon Linux.
  class AmazonLinux < RHEL

    # Amazon Linux version, i.e. '2014.09.1'. No default value.
    attr_accessor :amazon_version

    alias :distro_version :amazon_version

    # Return RHEL#rhel_version if specified, or a comparable
    # RHEL version if #amazon_version if specified.
    #
    # History of Amazon Linux releases:
    #
    # * 2011.09 upgraded to glibc 2.12, parity with RHEL 6
    #
    # * 2014.03 upgraded to 2.17, parity with RHEL 7
    #
    # Note however that Amazon is still behind RHEL 7 in other
    # respects (ex: systemd), and is ahead on other packages.
    def rhel_version
      super ||
        ( amazon_version &&
          ( ( version_gte?( amazon_version, [2014,3] ) && '7' ) ||
            ( version_gte?( amazon_version, [2011,9] ) && '6' ) ||
            '5' ) )
    end

    # Despite later versions being comparable to #rhel_version '7',
    # Amazon Linux has yet (2015.09) to migrate to systemd. Return
    # false.
    def systemd?
      false
    end

  end

end
