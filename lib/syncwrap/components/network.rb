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

require 'syncwrap/components/ubuntu'
require 'syncwrap/components/rhel'

module SyncWrap

  # Make updates to system configration for hostname and name
  # resolution. These changes are distro specific.
  class Network < Component

    # A default DNS domain name to use for name search, for addition
    # to /etc/resolver.conf, etc. (default: nil)
    attr_accessor :dns_domain

    def initialize( opts = {} )
      @dns_domain = nil
      super
    end

    def install
      update_hostname
      update_resolver
    end

    def update_hostname
      name = host.name

      case distro
      when RHEL
        # If HOSTNAME not already set correctly in network file,
        # backup, delete old line, append new line.
        sudo <<-SH
          if ! grep -q '^HOSTNAME=#{name}$' /etc/sysconfig/network; then
            cp -f /etc/sysconfig/network /etc/sysconfig/network~
            sed -i '/^HOSTNAME=.*/d' /etc/sysconfig/network
            echo 'HOSTNAME=#{name}' >> /etc/sysconfig/network
            hostname #{name}
          fi
        SH
      when Ubuntu
        sudo <<-SH
          if [ ! -e /etc/hostname -o "$(< /etc/hostname)" != "#{name}" ]; then
            echo #{name} > /etc/hostname
            hostname #{name}
          fi
        SH
      end
    end

    def update_resolver
      if dns_domain
        # (Temporary) inclusion direct to resolver.conf
        sudo <<-SH
          if ! grep -q 'search.* #{dns_domain}' /etc/resolver.conf; then
            cp -f /etc/resolver.conf /etc/resolver.conf~
            sed -i '/^search/d' /etc/resolver.conf
            echo 'search #{dns_domain}' >> /etc/resolver.conf
          fi
        SH

        case distro
        when RHEL
          # FIXME:
          warn "Network: not sure if resolver.conf change is permanent?"
        when Ubuntu
          f='/etc/network/interfaces'
          sudo <<-SH
            if ! grep -E -q '^\\s*dns-domain #{dns_domain}' #{f}; then
              cp -f #{f} #{f}~
              sed -r -i '/^\\s*dns-domain/d' #{f}
              echo '     dns-domain #{dns_domain}' >> #{f}
            fi
          SH
        end
      end
    end

  end

end
