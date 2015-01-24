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
require 'syncwrap/version_support'

# For distro class comparison only (pre-load for safety)
require 'syncwrap/components/debian'
require 'syncwrap/components/ubuntu'
require 'syncwrap/components/rhel'
require 'syncwrap/components/amazon_linux'

module SyncWrap

  # Make updates to system configration for hostname and name
  # resolution. These changes are distro specific.
  #
  # Host component dependencies: <Distro>
  class Network < Component
    include VersionSupport

    # A dns search list (a single domain or space delimited list of
    # domains) for addition to the resolv.conf search option,
    # etc. (default: nil)
    attr_accessor :dns_search

    alias :dns_domain  :dns_search
    alias :dns_domain= :dns_search=

    def initialize( opts = {} )
      @dns_search = nil
      super
    end

    def install
      update_hostname
      update_resolver
    end

    def update_hostname
      name = host.name
      if ( distro.is_a?( AmazonLinux ) ||
           ( distro.is_a?( RHEL ) && version_lt?( rhel_version, [7] ) ) )
        set_sysconfig_network( name )
      else
        set_etc_hostname( name )
      end
    end

    # Test if change to etc/hostname is needed. If so also immediately
    # set (in kernel) hostname.
    def set_etc_hostname( name )
      sudo <<-SH
        if [ ! -e /etc/hostname -o "$(< /etc/hostname)" != "#{name}" ]; then
          echo #{name} > /etc/hostname
          hostname #{name}
        fi
      SH
    end

    # Test if change to etc/sysconfig/network is needed. If so also
    # immediately set (in kernel) hostname.
    def set_sysconfig_network( name )
      # If not already set correctly, backup, delete old line, append
      # new line.
      sudo <<-SH
        if ! grep -q '^HOSTNAME=#{name}$' /etc/sysconfig/network; then
          cp -f /etc/sysconfig/network /etc/sysconfig/network~
          sed -i '/^HOSTNAME=.*/d' /etc/sysconfig/network
          echo 'HOSTNAME=#{name}' >> /etc/sysconfig/network
          hostname #{name}
        fi
      SH
    end

    def update_resolver
      if dns_search
        case distro
        when RHEL
          update_resolv_conf

          f='/etc/sysconfig/network-scripts/ifcfg-eth0'
          sudo <<-SH
            if ! grep -q '^SEARCH=.*#{dns_search}' #{f}; then
              cp -f #{f} #{f}~
              sed -i '/^SEARCH=/d' #{f}
              echo 'SEARCH="#{dns_search}"' >> #{f}
            fi
          SH

        when Debian
          if distro.is_a?( Ubuntu )
            # As of 12.04 - Precise; /etc/resolv.conf is a symlink that
            # should not be lost.
            update_resolv_conf( '/run/resolvconf/resolv.conf' )
          else
            update_resolv_conf
          end

          f='/etc/network/interfaces'
          sudo <<-SH
            if ! grep -E -q '^\\s*dns-search #{dns_search}' #{f}; then
              cp -f #{f} #{f}~
              sed -r -i '/^\\s*dns-search/d' #{f}
              echo '     dns-search #{dns_search}' >> #{f}
            fi
          SH

        end
      end
    end

    protected

    # Make a temporary adjustment to search domains directly to the
    # resolv.conf file.
    def update_resolv_conf( f = '/etc/resolv.conf' )
      sudo <<-SH
        if ! grep -q '^search.* #{dns_search}' #{f}; then
          cp -f #{f} #{f}~
          sed -i '/^search/d' #{f}
          echo 'search #{dns_search}' >> #{f}
        fi
      SH
    end

  end

end
