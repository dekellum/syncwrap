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
require 'syncwrap/common'

# Implements common remoting methods in terms of rake/remote_task (and
# thus Vlad compatible)
module SyncWrap::RemoteTask
  include SyncWrap::Common
  include Rake::DSL

  def initialize
    super

    # Defaults:
    set( :sudo_flags, %w[ -H ] )
    set( :rsync_flags, %w[ -rlpcb -ii ] )
  end

  # Implements SyncWrap::Common#run
  def run( *args )
    opts = args.last.is_a?( Hash ) && args.pop || {}

    exit_multi = opts[ :error ].nil? || opts[ :error ] == :exit

    args = cleanup_arg_lines( args, exit_multi )

    remote_task_current.run( *args )
  end

  # Implements SyncWrap::Common#sudo
  def sudo( *args )
    opts = args.last.is_a?( Hash ) && args.pop || {}

    flags = opts[ :flags ] || []
    if opts[ :user ]
      flags += [ '-u', opts[ :user ] ]
    end

    unless opts[ :shell ] == false
      exit_multi = opts[ :error ].nil? || opts[ :error ] == :exit
      cmd = cleanup_arg_lines( args, exit_multi )
      cmd = shell_escape_cmd( cmd.join( ' ' ) )
      cmd = "sh -c \"#{cmd}\""
    else
      cmd = cleanup_arg_lines( args, false )
    end

    remote_task_current.sudo( [ flags, cmd ] )
  end

  # Implements SyncWrap::Common#rsync
  def rsync( *args )
    remote_task_current.rsync( *args )
  end

  def target_host
    remote_task_current.target_host
  end

  # Implements Common#exec_conditional
  def exec_conditional
    yield
    0
  rescue Rake::CommandFailedError => e
    e.status
  end

  # Remove extra whitespace from multi-line and single arguments
  def cleanup_arg_lines( args, exit_error_on_multi )
    args.flatten.compact.map do |arg|
      alines = arg.split( $/ )
      if alines.length > 1 && exit_error_on_multi
        alines.unshift( "set -e" )
      end
      alines.map { |f| f.strip }.join( $/ )
    end
  end

  def shell_escape_cmd( cmd )
    cmd.gsub( /["$`\\]/ ) { |c| '\\' + c }
  end

  def remote_task( name, *args, &block )
    Rake::RemoteTask.remote_task( name, *args, &block )
  end

  def set( *args )
    Rake::RemoteTask.set( *args )
  end

  def host( host_name, *roles )
    Rake::RemoteTask.host( host_name, *roles )
  end

  def role( role_name, host = nil, args = {} )
    Rake::RemoteTask.role( role_name, host, args )
  end

  def remote_task_current
    Thread.current[ :task ] or raise "Not running from a RemoteTask"
  end
end
