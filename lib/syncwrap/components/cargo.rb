# coding: utf-8
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
require 'syncwrap/change_key_listener'

module SyncWrap

  # Provision to `cargo install`, optionally triggered by a state change key.
  #
  # Host component dependencies: SourceTree?, Rustc#cargo_command
  class Cargo < Component
    include PathUtil
    include ChangeKeyListener

    # Path to local crate directory containing Cargo.toml, etc.
    # (Default: SourceTree#remote_source_path)
    attr_writer :crate_path

    def crate_path
      @crate_path || remote_source_path
    end

    def crate_git
      @crate_git
    end

    protected

    # Hash of environment key/values to set on call to cargo install
    # (Default: {} → none)
    attr_accessor :cargo_install_env

    # User to perform the bundle install
    # (Default: :root)
    attr_writer :cargo_install_user

    # Array of features to use instead of the default features for builds
    # (Default: [] → none)
    attr_accessor :features

    def cargo_install_user
      @cargo_install_user
    end

    public

    def initialize( opts = {} )
      @crate_git = nil
      @crate_path = nil
      @cargo_install_env = {}
      @cargo_install_user = :root
      @features = []
      super
    end

    def install
      cargo_install if change_key.nil? || change_key_changes?
    end

    def cargo_install
      cmd = [ preamble, cargo_command, 'install' ]

      if crate_git
        raise "FIXME: Unsupported for now"
      elsif crate_path
        cmd += [ '--path', crate_path ]
      end

      unless features.empty?
        cmd += [ '--no-default-features', '--features', features.join(',') ]
      end

      if cargo_install_user == :root #default
        cmd += [ '--root', local_root ]
      end

      sh( cmd.join(' '), user: cargo_install_user )
    end

    protected

    def preamble
      setters = cargo_install_env.map do |k,v|
        k.to_s + '="' + v.gsub( /["\\]/ ) { |c| '\\' + c } + '"'
      end
      setters.join( ' ' )
    end

  end
end
