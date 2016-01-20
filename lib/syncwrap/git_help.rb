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

require 'syncwrap/path_util'

module SyncWrap

  # Utility methods for sync file/sources kept in a git repository.
  module GitHelp
    extend PathUtil

    # Raises RuntimeError if the git tree at path (default to caller's
    # path) is not clean
    def self.require_clean!( path = nil )
      path ||= caller_path( caller )
      delta = `cd #{path} && git status --porcelain -- . 2>&1`
      if delta.split( /^/ ).length > 0
        warn( "Commit or move these first:\n" + delta )
        raise "Git repo at #{path} not clean"
      end
    end

    # Return the abbreviated SHA-1 hash for the last git commit at
    # path
    def self.git_hash( path = nil )
      path ||= caller_path( caller )
      `cd #{path} && git log -n 1 --format='format:%h'`
    end

    # Return a lambda that will #require_clean! for callers path
    # before providing #git_hash. Use this for cases where you only want
    # to use a git hash when it is an accurate reflection of the local
    # file state. Since the test is deferred, it will only be required
    # for actions (i.e. image creation, etc.) that actually use it.
    def self.clean_hash
      cpath = caller_path( caller )
      lambda do
        require_clean!( cpath )
        git_hash( cpath )
      end
    end

  end

end
