#--
# Copyright (c) 2011-2013 David Kellum
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

# Common utility methods and variables.
module SyncWrap::Common

  # The prefix for local non-distro installs (default: /usr/local)
  attr_accessor :common_prefix

  def initialize
    super
    @common_prefix = '/usr/local'
  end

  # Return true if remote file exists, as per "test -e"
  def exist?( file )
    exec_conditional { run "test -e #{file}" } == 0
  end

  # Put files or entire directories to remote.
  #
  #   rput( src..., dest, {options} )
  #   rput( src, {options} )
  #
  # A trailing hash is interpreted as options, see below.
  #
  # If there is two or more remaining arguments, the last is
  # interpreted as the remote destination.  If there is a single
  # remaining argument, the destination is implied by finding its base
  # directory and prepending '/'. Thus for example:
  #
  #   rput( 'etc/gemrc', :user => 'root' )
  #
  # has an implied destination of: `/etc/`. The src and destination
  # are intrepreted as by `rsync`: glob patterns are expanded and
  # trailing '/' is significant.
  #
  # ==== Options
  # :user:: Files should be owned on destination by a user other than
  #         installer (ex: 'root') (implies sudo)
  # :perms:: Permissions to set for install files.
  # :excludes:: One or more rsync compatible --filter excludes, or
  #             :dev which excludes common developmoent tree droppings
  #             like '*~'
  def rput( *args )
    opts = args.last.is_a?( Hash ) && args.pop || {}

    if args.length == 1
      abspath = "/" + args.first
      abspath = File.dirname( abspath ) + '/' unless abspath =~ %r{/$}
    else
      abspath = args.pop
    end

    flags = []

    excludes = Array( opts[ :excludes ] )
    flags += excludes.map do |e|
      if e == :dev
        '--cvs-exclude'
      else
        "--filter=#{e}"
      end
    end

    if opts[ :perms ]
      flags << '-p'
      flags << "--chmod=#{opts[ :perms ]}"
    end

    if opts[ :user ]
      # Use sudo to place files at remote.
      user = opts[ :user ] || 'root'
      flags << ( if user != 'root'
                   "--rsync-path=sudo -u #{user} rsync"
                 else
                   "--rsync-path=sudo rsync"
                 end )
    end

    cmd = [ flags, args, [ target_host, abspath ].join(':') ].flatten.compact
    rsync( *cmd )

  end

  # Run args as shell command on the remote host. A line delimited
  # argument is interpreted as multiple commands, otherwise arguments
  # are joined as a single command.
  #
  # A trailing Hash is interpreted as options, see below.
  #
  # ==== options
  # :error:: Set the error handling mode: If `:exit`, causes "set -e" to
  #          be passed as the first line of a multi-line
  #          command. (Default: :exit)
  def run( *args )
    raise "Include a remoting-specific module, e.g. RemoteTask"
  end

  # Run args under sudo on remote host. A line delimited argument is
  # interpreted as multiple commands, otherwise arguments are joined
  # as a single command.
  #
  # A trailing Hash is interpreted as options, see below.
  #
  # ==== options
  # :user:: Run as specified user (default: root)
  # :flags:: Additional sudo flags
  # :shell:: Run command in a shell by wrapping it in sh -c "", and
  #          escaping quotes in the original joined args command.
  #          (default: true)
  # :error:: Set the error handling mode: If `:exit`, causes "set -e" to
  #          be passed as the first line of a multi-line
  #          command. (Default: :exit, only applies if :shell)
  def sudo( *args )
    raise "Include a remoting-specific module, e.g. RemoteTask"
  end

  # Return the exit status of the first non-zero command result, or 0
  # if all commands succeeded.
  def exec_conditional
    raise "Include a remoting-specific module, e.g. RemoteTask"
  end

  # Implement rsync as used by rput. Note that args should not be
  # passed through shell interpretation, eg run via system( Array )
  def rsync( *args )
    raise "Include a remoting-specific module, e.g. RemoteTask"
  end

  # Returns the current target host when called from a running task.
  def target_host
    raise "Include a remoting-specific module, e.g. RemoteTask"
  end

end
