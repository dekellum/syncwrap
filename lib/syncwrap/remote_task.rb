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

require 'rake/remote_task'

require 'syncwrap/base'

module SyncWrap::RemoteTask

  def initialize
    super

    # Defaults:
    set( :sudo_flags, %w[ -H ] )
    set( :rsync_flags, %w[ -rlpcb -ii ] )
  end

  def set( *args )
    Rake::RemoteTask.set( *args )
  end

  # Run args as shell command on the remote host. A line delimited
  # argument is interpreted as multiple commands, otherwise arguments
  # are joined as a single command.
  #
  # A trailing Hash is interpreted as options, however no options are
  # currently interpreted.
  def run( *args )
    opts = args.last.is_a?( Hash ) && args.pop
    args = cleanup_arg_lines( args )

    #FIXME: Should cleanup multi-line commands
    Thread.current[ :task ].run( *args )
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
  def sudo( *args )
    opts = args.last.is_a?( Hash ) && args.pop || {}

    flags = opts[ :flags ] || []
    if opts[ :user ]
      flags += [ '-u', opts[ :user ] ]
    end

    cmd = cleanup_arg_lines( args )

    unless opts[ :shell ] == false
      cmd = cmd.join( ' ' ).gsub( /"/, '\"' )
      cmd = "sh -c \"#{cmd}\""
    end

    Thread.current[ :task ].sudo( [ flags, cmd ] )
  end

  # Remove extra whitespace from multi-line and single arguments
  def cleanup_arg_lines( args )
    args.flatten.compact.map do |arg|
      arg.split( $/ ).map { |f| f.strip }.join( $/ )
    end
  end

  def rsync( *args )
    Thread.current[ :task ].rsync( *args )
  end

  # Return exit status of the first non-zero command result, or 0 if
  # all command succeeded
  def exec_conditional
    yield
    0
  rescue Rake::CommandFailedError => e
    e.status
  end

end
