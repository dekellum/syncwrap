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

module SyncWrap

  # A Support module for parsing and comparing version strings.
  module VersionSupport

    protected

    # Convert version decimal String to Array of Integer or String
    # values. The characters '.' and '-' are treated as
    # delimiters. Any remaining non-digit in a segment results in a
    # String being returned for that segment. Return v if not a
    # String (incl nil).
    def version_string_to_a( v )
      if v.is_a?( String )
        v.split(/[.\-]/).map do |p|
          if p =~ /^\d+$/
            p.to_i
          else
            p
          end
        end
      else
        v
      end
    end

    # Return true if v1 and v2 are not nil, (auto converted) array
    # positions are type compatible and compare as v1 >= v2.
    def version_gte?( v1, v2 )
      v1 = version_string_to_a( v1 )
      v2 = version_string_to_a( v2 )
      c = v1 && v2 && ( v1 <=> v2 ) #-> nil for String/Integer mix
      c && c >= 0
    end

    # Return true if v1 and v2 are not nil, (auto converted) array
    # positions are type compatible and compare v1 < v2.
    def version_lt?( v1, v2 )
      v1 = version_string_to_a( v1 )
      v2 = version_string_to_a( v2 )
      c = v1 && v2 && ( v1 <=> v2 ) #-> nil for String/Integer mix
      c && c < 0
    end
  end

end
