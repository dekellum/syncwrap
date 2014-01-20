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

require 'syncwrap/base'

require 'syncwrap/component'
require 'syncwrap/context'
require 'syncwrap/host'

module SyncWrap

  class CommandFailure < RuntimeError
  end

  class NestingError < RuntimeError
  end

  class Space

    def initialize
      @roles = Hash.new { |h,k| h[k] = [] }
      @hosts = {}
    end

    # Define/access a Role by symbol
    # Additional args are interpreted as Components to add to this
    # role.
    def role( symbol, *args )
      @roles[ symbol.to_sym ] += args.flatten.compact
    end

    # Define/access a Host by name
    # Additional args are interpreted as role symbols or (direct)
    # Components to add to this Host. Each role will only be added
    # once. A final Hash argument is interpreted as and reserved for
    # future options.
    def host( name, *args )
      opts = args.last.is_a?( Hash ) && args.pop || {}
      host = @hosts[ name ] ||= Host.new( self, name )
      host.add( *args )
      host
    end

    # FIXME: misc default args for ssh, sudo, i.e:
    # sudo_flags: ['-H']
    # ssh_flags: %w[ -i ./key.pem -l ec2-user ]
    # Option to use example ssh-flags for Users setup only?

    # FIXME: Host name to ssh name strategies go here

    # FIXME: Progamatic interface for execution
  end

end
