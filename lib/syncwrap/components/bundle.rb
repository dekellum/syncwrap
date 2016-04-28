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

require 'syncwrap/component'

require 'syncwrap/git_help'
require 'syncwrap/path_util'
require 'syncwrap/change_key_listener'

module SyncWrap

  # Provision to `bundle install`, optionally triggered by a state change key.
  #
  # Host component dependencies: RunUser?, SourceTree?, BundlerGem
  class Bundle < Component
    include PathUtil
    include ChangeKeyListener

    # Path to the Gemfile(.lock)
    # (Default: SourceTree#remote_source_path)
    attr_writer :bundle_path

    def bundle_path
      @bundle_path || remote_source_path
    end

    # The path to install bin stubs, if any. If relative, it is
    # relative to #bundle_path.
    # (Default: sbin; directory in #bundle_path)
    # The default is purposefully not 'bin', so as to avoid clashes
    # with source trees that already have a 'bin', for example that
    # contain gem source as well.
    attr_accessor :bundle_install_bin_stubs

    protected

    # Hash of environment key/values to set on call to bundle install
    # (Default: {} -> none)
    attr_accessor :bundle_install_env

    # User to perform the bundle install
    # (Default: RunUser#run_user)
    attr_writer :bundle_install_user

    def bundle_install_user
      @bundle_install_user || run_user
    end

    # The path to bundle install dependencies. If relative, it is
    # relative to #bundle_path.
    # (Default: ~/.gem -> the #bundle_install_user gems)
    attr_accessor :bundle_install_path

    public

    def initialize( opts = {} )
      @bundle_path = nil
      @bundle_install_env = {}
      @bundle_install_path = '~/.gem'
      @bundle_install_user = nil
      @bundle_install_bin_stubs = 'sbin'
      super
    end

    def install
      bundle_install if change_key.nil? || change_key_changes?
    end

    def bundle_install
      sh( "( cd #{bundle_path}", close: ')', user: bundle_install_user ) do
        cmd = [ preamble, bundle_command, '_' + bundler_version + '_', 'install' ]

        if bundle_install_path
          cmd += [ '--path', bundle_install_path ]
        end

        if bundle_install_bin_stubs
          cmd += [ '--binstubs', bundle_install_bin_stubs ]
        end

        sh( cmd.join(' '), user: bundle_install_user )
      end
    end

    protected

    def preamble
      setters = bundle_install_env.map do |k,v|
        k.to_s + '="' + v.gsub( /["\\]/ ) { |c| '\\' + c } + '"'
      end
      setters.join( ' ' )
    end

  end
end
