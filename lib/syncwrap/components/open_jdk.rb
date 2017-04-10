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

# For distro class comparison only (pre-load for safety)
require 'syncwrap/components/rhel'
require 'syncwrap/components/debian'
require 'syncwrap/components/ubuntu'
require 'syncwrap/components/arch'
require 'syncwrap/version_support'

module SyncWrap

  # Provision an OpenJDK via Linux distro managed packages.
  #
  # For simplicity, this component only supports the full JDK (runtime
  # and compiler) and not the JRE (runtime only).  Note that
  # on older Debian-based distros, installing 'openjdk-7-jdk' is
  # necessary for javac, but ends up pulling X11 and leads to
  # signficant system bloat. See:
  #
  # https://bugs.launchpad.net/ubuntu/+source/openjdk-6/+bug/257857
  #
  # As of Ubuntu 16.04, there is an 'openjdk-8-jdk-headless' package
  # which this will use if applicable.
  #
  # Host component dependencies: <Distro>
  #
  # Oracle, Java, and OpenJDK are registered trademarks of Oracle
  # and/or its affiliates.
  # See http://openjdk.java.net/legal/openjdk-trademark-notice.html
  class OpenJDK < Component
    include VersionSupport

    # The JDK major and/or minor version number, i.e "1.7" or "7" is 7.
    # Marketing picked the version scheme.
    attr_accessor :jdk_major_minor

    def initialize( opts = {} )
      @jdk_major_minor = 7

      super
    end

    # Distro and version dependent JDK installation directory.
    def jdk_dir
      case distro
      when RHEL
        "/usr/lib/jvm/java-1.#{jdk_major_minor}.0"
      when Debian
        "/usr/lib/jvm/java-#{jdk_major_minor}-openjdk-amd64"
      when Arch
        "/usr/lib/jvm/java-#{jdk_major_minor}-openjdk"
      else
        raise ContextError, "Unknown distro jdk_dir"
      end
    end

    # Install distro packages, including development headers for JNI
    # dependents like Hashdot.
    def install
      case distro
      when RHEL
        dist_install( "java-1.#{jdk_major_minor}.0-openjdk",
                      "java-1.#{jdk_major_minor}.0-openjdk-devel" )
      when Debian
        if jdk_major_minor >= 8 &&
           distro.is_a?( Ubuntu ) &&
           version_gte?( distro.ubuntu_version, [16,4] )
          # FIXME: This jdk-headless package option may be(come)
          # available on upstream Debian as well.
          dist_install( "openjdk-#{jdk_major_minor}-jdk-headless" )
        else
          dist_install( "openjdk-#{jdk_major_minor}-jdk" )
        end
      when Arch
        dist_install( "jdk#{jdk_major_minor}-openjdk" )
      else
        raise ContextError, "Unknown distro type"
      end
    end

  end

end
