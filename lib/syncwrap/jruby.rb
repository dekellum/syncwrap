#--
# Copyright (c) 2011-2012 David Kellum
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

require 'syncwrap/base'
require 'syncwrap/common'

module SyncWrap::JRuby
  include SyncWrap::Common

  attr_accessor :jruby_version

  attr_accessor :jruby_gem_command

  attr_accessor :jruby_gem_install_args

  def initialize
    super

    @jruby_version = '1.6.7'
    @jruby_gem_command = 'jgem'
    @jruby_gem_install_args = %w[ --no-rdoc --no-ri ]
  end

  def jruby_install
    unless exist?( "#{common_prefix}/lib/jruby/jruby-#{jruby_version}" )
      jruby_install!
    end
  end

  def jruby_install!
    url = ( "http://jruby.org.s3.amazonaws.com/downloads/#{jruby_version}/" +
            "jruby-bin-#{jruby_version}.tar.gz" )

    root = "#{common_prefix}/lib/jruby"

    sudo <<-SH
      mkdir -p #{root}
      mkdir -p #{root}/gems
      curl -sSL #{url} | tar -C #{root} -zxf -
      cd #{root} && ln -sf jruby-#{jruby_version} jruby
      cd #{common_prefix}/bin && ln -sf ../lib/jruby/jruby/bin/jirb .
    SH

    rput( 'usr/local/bin/', :excludes => :dev, :user => 'root' )
  end

  # Return true if gem is already installed.
  def jruby_check_gem( gems, opts )
    query = [ jruby_gem_command, 'query', '-i',
              jruby_gem_version_flags( opts[ :version ] ),
              '-n', gems, '>/dev/null' ].flatten.compact

    status = exec_conditional do
      send( opts[ :user ] ? :run : :sudo, query )
    end
    ( status == 0 )
  end

  # Install the specified gem(s) with options
  def jruby_install_gem( gems, opts = {} )
    if opts[ :check ] && jruby_check_gem( gems, opts )
      false
    else
      cmd = [ jruby_gem_command, 'install',
              jruby_gem_install_args,
              ( '--user-install' if opts[ :user ] ),
              jruby_gem_version_flags( opts[ :version ] ),
              gems ].flatten.compact
      send( opts[ :user ] ? :run : :sudo, cmd )
      true
    end
  end

  def jruby_gem_version_flags( reqs )
    Array( reqs ).flatten.compact.map { |req| "-v'#{req}'" }
  end

end
