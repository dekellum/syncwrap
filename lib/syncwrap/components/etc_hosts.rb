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

module SyncWrap

  # Provision/update an RFC 952 /etc/hosts file for "internal"
  # intra-Space host resolution. This can be used for simple internal
  # network resolution instead of DNS.
  #
  # Host component dependencies: none
  class EtcHosts < Component

    def initialize( opts = {} )
      super
    end

    def install
      rput( "etc/hosts", user: :root )
    end

    def etc_host_table
      host.space.hosts.map do |h|
        [ h[ :internal_ip ] || "# internal_ip?", [ h[ :name ] ] ]
      end
    end

  end

end
