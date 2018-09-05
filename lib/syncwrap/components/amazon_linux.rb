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

require 'syncwrap/components/rhel'

module SyncWrap

  # Customizations for Amazon Linux.
  class AmazonLinux < RHEL

    # Amazon Linux version, e.g. '2014.09.1' or '2017.12'. No default
    # value.
    attr_accessor :amazon_version

    alias :distro_version :amazon_version

    # Return RHEL#rhel_version if specified, or a comparable RHEL
    # version if #amazon_version is specified. Beyond Amazon Linux
    # 2014.03 this default mapping is fixed at RHEL 7.
    #
    # Relevant history:
    #
    # * 2011.09 upgraded to glibc 2.12, parity with RHEL 6
    #
    # * 2014.03 upgraded to glibc 2.17, parity with RHEL 7
    #
    def rhel_version
      super ||
        ( amazon_version &&
          ( ( version_gte?( amazon_version, [2014,3] ) && '7' ) ||
            ( version_gte?( amazon_version, [2011,9] ) && '6' ) ||
            '5' ) )
    end

    # Despite earlier versions being otherwise comparable to RHEL 7,
    # the first version of Amazon Linux with systemd is 2017.12.
    def systemd?
      if @systemd.nil? && amazon_version
        @systemd = version_gte?( amazon_version, [2017,12] )
      end
      @systemd
    end

  end

end
