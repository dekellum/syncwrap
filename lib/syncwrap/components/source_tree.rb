#--
# Copyright (c) 2011-2018 David Kellum
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
  # The remote source directory will be owned by the RunUser#run_user
  #
  # Host component dependencies: RunUser
  class SourceTree < Component
    include PathUtil

    # Local path to root directory in which #source_dir is found
    # (Default: <sync-file directory>/..)
    attr_accessor :local_source_root

    # Source directory name (required)
    attr_accessor :source_dir

    # Remote path to the root directory in which #remote_dir should be
    # installed. (Default: RunUser#run_dir)
    attr_writer :remote_source_root

    def remote_source_root
      @remote_source_root || run_dir
    end

    # Remote directory name (Default: #source_dir)
    attr_writer :remote_dir

    def remote_dir
      @remote_dir || source_dir
    end

    # File mode as integer for the #remote_dir (Default: 0755)
    attr_accessor :remote_dir_mode

    protected

    # Require local source_dir to be clean per Git before #rput of the
    # tree. (Default: true)
    attr_writer :require_clean

    def require_clean?
      @require_clean
    end

    # The state key (or Array of keys) to set to if there are any
    # changes to the tree
    # (Default: :source_tree)
    attr_accessor :change_key

    # Any additional options for the rput (Default: {} -> none)
    attr_accessor :rput_options

    # A file name found at the root of source_dir containing the
    # complete list of files to transfer. The value `true` is a synonym
    # for 'Manifest.txt'. (Default: nil -> none)
    attr_accessor :manifest

    public

    def initialize( opts = {} )
      opts = opts.dup
      clr = opts.delete(:caller) || caller
      @local_source_root = path_relative_to_caller( '..', clr )
      @source_dir = nil
      @remote_dir = nil
      @remote_dir_mode = 0755
      @remote_source_root = nil
      @require_clean = true
      @rput_options = {}
      @change_key = :source_tree
      @manifest = nil
      super

      raise "SourceTree#source_dir not set" unless source_dir
    end

    def remote_source_path
      File.join( remote_source_root, remote_dir )
    end

    def install
      mkdir_run_user( remote_source_path, mode: remote_dir_mode )
      changes = sync_source
      on_change( changes ) unless changes.empty?
      changes
    end

    protected

    def local_source_path
      File.join( local_source_root, source_dir )
    end

    def on_change( changes )
      unless changes.empty? || change_key.nil?
        Array(change_key).each do |key|
          state[ key ] ||= []
          state[ key ] += changes
        end
      end
    end

    def sync_source
      GitHelp.require_clean!( local_source_path ) if require_clean?
      opts = { erb_process: false,
               excludes: [ :dev, '.bundle/' ],
               user: run_user,
               sync_paths: [ local_source_root ] }
      mf = manifest
      if mf
        mf = 'Manifest.txt' if mf == true
        mf = File.join( local_source_root, source_dir, mf )
        opts[:manifest] = mf
      end
      opts.merge!( rput_options )
      rput( source_dir + '/', remote_source_path, opts )
    end

  end
end
