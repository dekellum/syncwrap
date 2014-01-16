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

module SyncWrap

  # Provision JRuby by direct download from public S3 repo. Includes
  # utility methods for checking and installing JRuby gems.
  class JRuby < Component

    # JRuby version to install (default: 1.6.8)
    attr_accessor :jruby_version

    # The name of the gem command to be installed/used (default: jgem)
    attr_accessor :jruby_gem_command

    # Default gem install arguments (default: --no-rdoc, --no-ri)
    attr_accessor :jruby_gem_install_args

    def initialize( opts = {} )
      @jruby_version = '1.6.8'
      @jruby_gem_command = 'jgem'
      @jruby_gem_install_args = %w[ --no-rdoc --no-ri ]

      super
    end

    def jruby_dist_path
      "#{local_root}/lib/jruby/jruby-#{jruby_version}"
    end

    def jruby_gemrc_path
      "#{jruby_dist_path}/etc"
    end

    # Install jruby if the jruby_version is not already present.
    def install
      jruby_install
      jruby_install_gemrc
    end

    # Install gemrc file to jruby_gemrc_path
    def jruby_install_gemrc
      rput( 'etc/gemrc', jruby_gemrc_path, user: :root )
    end

    def jruby_bin_url
      [ 'http://jruby.org.s3.amazonaws.com/downloads',
        jruby_version,
        "jruby-bin-#{jruby_version}.tar.gz" ].join( '/' )
    end

    # Install jruby, including usr/local/bin local contents
    def jruby_install

      root = "#{local_root}/lib/jruby"

      sudo <<-SH
        if [ ! -d #{jruby_dist_path} ]; then
          mkdir -p #{root}
          mkdir -p #{root}/gems
          curl -sSL #{jruby_bin_url} | tar -C #{root} -zxf -
          mkdir -p #{jruby_gemrc_path}
          cd #{root} && ln -sfn jruby-#{jruby_version} jruby
          cd #{local_root}/bin && ln -sf ../lib/jruby/jruby/bin/jirb .
        fi
      SH

      # FIXME: Assumes /usr/local. Move to jruby/bin/*
      rput( 'usr/local/bin/', excludes: :dev, user: :root )
    end

    # Return true if gem is already installed.
    # ==== Options
    # :version:: Version specifier array, like in spec. files
    #            (default: none, i.e. latest)
    # :user_install:: If true, perform check as the current user, else
    #                 system install with sudo (default: false )
    def jruby_check_gem( gems, opts = {} )
      query = [ jruby_gem_command, 'query', '-i',
                jruby_gem_version_flags( opts[ :version ] ),
                '-n', gems, '>/dev/null' ].flatten.compact

      # FIXME: exec_conditional? Alternative to send?, join ' '
      status = exec_conditional do
        send( opts[ :user_install ] ? :run : :sudo, query )
      end
      ( status == 0 )
    end

    # Install the specified gem(s)
    # ==== Options
    # :version:: Version specifier array, like in spec. files
    #            (default: none, i.e. latest)
    # :user_install:: If true, perform a --user-install as the current
    #                 user, else system install with sudo (default:
    #                 false )
    def jruby_install_gem( gems, opts = {} )
      if opts[ :check ] && jruby_check_gem( gems, opts )
        false
      else
        cmd = [ jruby_gem_command, 'install',
                jruby_gem_install_args,
                ( '--user-install' if opts[ :user_install ] ),
                jruby_gem_version_flags( opts[ :version ] ),
                gems ].flatten.compact
        # FIXME: Alternative to send?, join ' '
        send( opts[ :user_install ] ? :run : :sudo, cmd )
        true
      end
    end

    def jruby_gem_version_flags( reqs )
      Array( reqs ).flatten.compact.map { |req| "-v'#{req}'" }
    end

  end

end
