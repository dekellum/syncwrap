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

require 'syncwrap/component'
require 'syncwrap/ruby_support'
require 'syncwrap/version_support'

module SyncWrap

  # Provision JRuby (jruby.org - Ruby on the Java Virtual Machine) by
  # direct download from public S3 repo. Includes utility methods for
  # checking and installing JRuby gems.
  #
  # Host component dependencies: <Distro>
  class JRubyVM < Component
    include VersionSupport
    include RubySupport

    # JRuby version to install (default: 1.7.17)
    attr_accessor :jruby_version

    def initialize( opts = {} )
      @jruby_version = '1.7.17'

      super( { ruby_command: 'jruby',
                gem_command: 'jgem' }.merge( opts ) )
    end

    def jruby_dist_path
      "#{local_root}/lib/jruby/jruby-#{jruby_version}"
    end

    def gemrc_path
      "#{jruby_dist_path}/etc"
    end

    def jruby_gem_home
      "#{local_root}/lib/jruby/gems"
    end

    # Install jruby if the jruby_version is not already present.
    def install
      jruby_install
      install_gemrc
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
          mkdir -p #{gemrc_path}
          cd #{root} && ln -sfn jruby-#{jruby_version} jruby
          cd #{local_root}/bin && ln -sf ../lib/jruby/jruby/bin/jirb .
        fi
      SH

      rput( 'jruby/bin/', "#{local_root}/bin/", excludes: :dev, user: :root )
    end

    # See RubySupport#gem_install for usage.
    #
    # The jruby jgem command tends to be slow on virtual hardware.
    # This implementation adds a faster short-circuit when an exact,
    # single :version is given that avoids calling jgem if the rubygems
    # same version gemspec file is found.
    def gem_install( gem, opts = {} )
      version = Array( opts[ :version ] )
      ver = (version.length == 1) && version[0] =~ /^=?\s*([0-9]\S+)/ && $1

      unless ( opts[:check] || opts[:user_install] ||
               opts[:minimize] == false || opts[:spec_check] == false ||
               ver.nil? )

        specs = [ "#{jruby_gem_home}/specifications/#{gem}-#{ver}-java.gemspec",
                  "#{jruby_gem_home}/specifications/#{gem}-#{ver}.gemspec" ]

        sudo( "if [ ! -e '#{specs[0]}' -a ! -e '#{specs[1]}' ]; then",
              close: "fi" ) do
          super
        end
      else
        super
      end

    end

    alias :jruby_gem_install :gem_install

    protected

    def min_deps_supported?
      version_gte?( jruby_version, [1,7,5] )
    end

    def jruby_gem_version_flags( reqs )
      Array( reqs ).flatten.compact.map { |req| "-v'#{req}'" }
    end

  end

end
