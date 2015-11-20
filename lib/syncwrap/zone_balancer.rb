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
  # availability zones for fault tolarance purposes.
  class ZoneBalancer

    # One or more role symbols for which to compare existing host
    # zones. If empty, all hosts will be compared.
    # Default: []
    attr_accessor :roles

    # Required list of zone String names across which to balance new
    # hosts. The zone order is honored when frequency of current hosts
    # is the same (including 0). If not set, no zone will be selected
    # by the zone method, leaving selection to AWS.
    attr_accessor :zones

    def initialize( opts = {} )
      opts = opts.dup
      @space = opts.delete( :space ) || Space.current
      @roles = []
      @zones = nil
      opts.each { |name, val| send( name.to_s + '=', val ) }
    end

    # Returns a ruby Proc which when called will return the next, best
    # pick of availability zone.
    def zone
      method :next_zone
    end

    def next_zone
      return nil unless @zones && !@zones.empty?
      hosts = @space.hosts
      unless @roles.empty?
        hosts = hosts.select do |h|
          h.roles.any? { |r| @roles.include?( r ) }
        end
      end
      zfreqs = {}
      @zones.each { |z| zfreqs[z] = 0 }
      czones = hosts.map { |h| h[:availability_zone] }.compact
      czones.each { |z| zfreqs[z] += 1 if zfreqs.has_key?( z ) }

      # Sort by ascending frequency (lowest first). Keep order stable
      # from original @zones, when frequency tied.
      # Return the first (least frequent, zones stables) zone.
      n = 0
      zfreqs.sort_by { |_,f| [ f, (n+=1) ] }.first[0]
    end

  end

end
