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

require 'syncwrap/git_help'
require 'syncwrap/path_util'

module SyncWrap

  # Install/synchronize a source tree to remotes via rput. By default
  # assumes the local source tree is in a Git DVCS repository and
  # checks that it is clean before executing.
  #
  # If any changes to the source tree occur, performs a bundle_install
  # if the bundle_command is defined (typically via Bundler), and a
  # Gemfile is found at top of source tree.
  #
  # Host component dependencies: RunUser, Bundler (optional)
  class SourceBundle < Component
    include PathUtil

    # Local path to root directory in which #source_dir is found
    # (Default: <sync-file directory>/..)
    attr_accessor :local_source_root

    # Source directory name (required)
    attr_accessor :source_dir

    # Remote path to the root directory in which #source_dir should be
    # installed.
    # (Default: run_dir, as per RunUser#run_dir)
    attr_writer :remote_source_root

    def remote_source_root
      @remote_source_root || run_dir
    end

    # Require local source_dir to be clean per Git before #rput of the
    # tree. (Default: true)
    attr_writer :require_clean

    def require_clean?
      @require_clean
    end

    # Any additional options for the rput (Default: {} -> none)
    attr_accessor :rput_options

    def initialize( opts = {} )
      opts = opts.dup
      clr = opts.delete(:caller) || caller
      @local_source_root = path_relative_to_caller( '..', clr )
      @source_dir = nil
      @remote_source_root = nil
      @require_clean = true
      @rput_options = {}
      super

      raise "SourceBundle#source_dir not set" unless source_dir
    end

    def install
      changes = sync_source
      install_on_change( changes ) unless changes.empty?
      changes
    end

    protected

    def install_on_change( changes )
      bundle_install if defined?( bundle_command )
    end

    def bundle_install
      rudo( "( cd #{remote_source_path}", close: ')' ) do
        rudo( 'if [ -f Gemfile ]; then', close: 'fi' ) do
          bundle_install!
        end
      end
    end

    def bundle_install!
      rudo "#{bundle_command} install --path ~/.gem --binstubs ./bin"
    end

    def sync_source
      GitHelp.require_clean!( local_source_path ) if require_clean?
      opts = { erb_process: false,
               excludes: [ :dev, '.bundle/' ],
               user: run_user,
               sync_paths: [ local_source_root ] }.
        merge( rput_options )
      rput( source_dir, remote_source_root, opts )
    end

    def local_source_path
      File.join( local_source_root, source_dir )
    end

    def remote_source_path
      File.join( remote_source_root, source_dir )
    end

  end
end
