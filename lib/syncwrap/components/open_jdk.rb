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
require 'syncwrap/components/ubuntu'

module SyncWrap

  # Provision an OpenJDK via Linux distro managed packages.
  #
  # Oracle, Java, and OpenJDK are registered trademarks of Oracle
  # and/or its affiliates.
  # See http://openjdk.java.net/legal/openjdk-trademark-notice.html.
  class OpenJDK < Component

    # The JDK major and/or minor version number, i.e "1.7" or "7" is 7.
    # Marketing picked the version scheme.
    attr_accessor :jdk_major_minor

    def initialize( opts = {} )
      @jdk_major_minor = 7

      super
    end

    def jdk_dir
      if distro.is_a?( RHEL )
        "/usr/lib/jvm/java-1.#{jdk_major_minor}.0"
      elsif distro.is_a?( Ubuntu )
        "/usr/lib/jvm/java-#{jdk_major_minor}-openjdk-amd64"
      else
        raise "Unknown distro jdk_dir"
      end
    end

    # Install including development headers for things like Hashdot.
    def install
      if distro.is_a?( RHEL )
        dist_install( "java-1.#{jdk_major_minor}.0-openjdk",
                      "java-1.#{jdk_major_minor}.0-openjdk-devel" )
      elsif distro.is_a?( Ubuntu )
        dist_install( "openjdk-#{jdk_major_minor}-jdk" )
      else
        raise "Unknown distro type"
      end
    end

  end

end
