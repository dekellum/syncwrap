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

module SyncWrap

  # A Support module for Ruby VM components, also providing gem
  # handling utilties which are largely common to all Ruby VMs.
  module RubySupport

    # The name of the gem command to be installed/used (default: gem)
    attr_accessor :gem_command

    # Default gem install arguments (default: --no-rdoc, --no-ri)
    attr_accessor :gem_install_args

    def initialize( *args )
      @gem_command = 'gem'
      @gem_install_args = %w[ --no-rdoc --no-ri ]

      super( *args )
    end

    def gemrc_path
      "/etc/gemrc"
    end

    # Install gemrc file to gemrc_path
    def install_gemrc
      rput( 'etc/gemrc', gemrc_path, user: :root )
    end

    # Install the specified gem.
    #
    # === Options
    #
    # :version:: Version specifier array or single value, like in a
    #            gemspec. (Default: nil -> latest) Examples:
    #
    #              '1.1.0'
    #              '~> 1.1'
    #              ['>=1.0', '<1.2']
    #
    # :user_install:: If true, perform a --user-install as the current
    #                 user.  Otherwise system install with sudo (the
    #                 default, false).
    #
    # :check:: If true, capture output and return the number of gems
    #          actually installed.  Combine with :minimize to only
    #          install what is required, and short circuit when zero
    #          gems installed. (Default: false)
    #
    # :minimize:: Use --conservative and --minimal-deps (rubygems
    #             2.1.5+, #min_deps_supported?) flags to reduce
    #             installs to the minimum required to satisfy the
    #             version requirements.  (Default: true)
    #
    def gem_install( gem, opts = {} )
      cmd = [ gem_command, 'install',
              gem_install_args,
              ( '--user-install' if opts[ :user_install ] ),
              ( '--conservative' if opts[ :minimize] != false ),
              ( '--minimal-deps' if opts[ :minimize] != false &&
                min_deps_supported? ),
              gem_version_flags( opts[ :version ] ),
              gem ].flatten.compact.join( ' ' )

      shopts = opts[ :user_install ] ? {} : {user: :root}

      if opts[ :check ]
        _,out = capture( cmd, shopts.merge!( accept: 0 ) )

        count = 0
        out.split( "\n" ).each do |oline|
          if oline =~ /^\s+(\d+)\s+gem(s)?\s+installed/
            count = $1.to_i
          end
        end
        count
      else
        sh( cmd, shopts )
      end

    end

    protected

    def min_deps_supported?
      true
    end

    def gem_version_flags( reqs )
      Array( reqs ).flatten.compact.map { |req| "-v'#{req}'" }
    end

  end

end