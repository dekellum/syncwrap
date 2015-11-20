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

module SyncWrap

  # Utility for balancing new hosts accross multiple (AWS)
  # availability zones for fault tolarance.
  module ZoneBalancer

    # Returns a ruby Proc which when called will return the best
    # pick of availability zone, via #next_zone
    def self.zone( zones, roles )
      lambda do
        next_zone( zones, roles )
      end
    end

    # Return the next best zone from the zones Array of fymbols,
    # preferring the least frequent :availability_zone of existing
    # hosts in the specified roles (or if empty, all hosts).
    def self.next_zone( zones, roles = [] )
      if zones
        hosts = filter_hosts( Space.current.hosts, roles )
        zfreqs = {}
        zones.each { |z| zfreqs[z] = 0 }
        czones = hosts.map { |h| h[:availability_zone] }.compact
        czones.each { |z| zfreqs[z] += 1 if zfreqs.has_key?( z ) }

        # Sort by ascending frequency (lowest first). Keep order stable
        # from original zones, when frequency tied.
        # Return the first (least frequent, zones stables) zone.
        n = 0
        zfreqs.sort_by { |_,f| [ f, (n+=1) ] }.first[0]
      end
    end

    private

    def self.filter_hosts( hosts, roles )
      unless roles.empty?
        hosts = hosts.select do |h|
          h.roles.any? { |r| roles.include?( r ) }
        end
      end
      hosts
    end

  end

end
