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

  def run( *args )
    #FIXME: Should cleanup multi-line commands
    Thread.current[ :task ].run( *args )
  end

  def sudo( *args )
    #FIXME: Can't pass sudo -u, etc.
    #FIXME: Should cleanup multi-line commands
    cmd = args.flatten.compact.join( ' ' ).gsub( /"/, '\"' )
    cmd = "sh -c \"#{cmd}\""
    Thread.current[ :task ].sudo( cmd )
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
