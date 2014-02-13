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

require 'pathname'

module SyncWrap

  # Utility methods for handling paths.
  module PathUtil

    private

    def caller_path( clr )
      clr.first =~ /^([^:]+):/ && File.dirname( $1 )
    end

    # Unless rpath is already absolute, expand it relative to the
    # calling file, as computed from passed in clr (use your
    # Kernel#caller)
    def path_relative_to_caller( rpath, clr ) # :doc:
      unless rpath =~ %r{^/}
        from = caller_path( clr )
        rpath = File.expand_path( rpath, from ) if from
      end
      rpath
    end

    # Return path relative to PWD if the result is shorter, otherwise
    # return input path. Preserves any trailing '/'.
    def relativize( path )
      p = Pathname.new( path )
      unless p.relative?
        p = p.relative_path_from( Pathname.pwd ).to_s
        p += '/' if path[-1] == '/'
        path = p if p.length < path.length
      end
      path
    end

  end

end
