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

require 'syncwrap/common'

# Provisions for a (daemon) run user and var directory. Utilities for
# working with the same.
module SyncWrap::UserRun
  include SyncWrap::Common

  # A user for running deployed daemons, jobs (default: 'runr')
  attr_accessor :user_run

  # A group for running (default: 'runr')
  attr_accessor :user_run_group

  # Directory for persistent data, logs. (default: /var/local/runr)
  attr_accessor :user_run_dir

  def initialize
    super

    @user_run       = 'runr'
    @user_run_group = 'runr'

    @user_run_dir   = '/var/local/runr'
  end

  # Create and set owner/permission of run_dir, such that user_run may
  # create new directories there.
  def user_run_dir_setup
    sudo <<-SH
      mkdir -p #{user_run_dir}
      chown #{user_run}:#{user_run_group} #{user_run_dir}
      chmod 775 #{user_run_dir}
    SH
  end

  # Create and set owner/permission of a named service directory under
  # user_run_dir.
  def user_run_service_dir_setup( sname, instance = nil )
    sdir =  user_run_service_dir( sname, instance )

    sudo <<-SH
      mkdir -p #{sdir}
      chown #{user_run}:#{user_run_group} #{sdir}
      chmod 775 #{sdir}
    SH
  end

  def user_run_service_dir( sname, instance = nil )
    "#{user_run_dir}/" + [ sname, instance ].compact.join( '-' )
  end

  # As per SyncWrap::Common#rput with :user => user_run
  def user_run_rput( *args )
    opts = args.last.is_a?( Hash ) && args.pop || {}
    opts[ :user ] = user_run
    args.push( opts )
    rput( *args )
  end

  # Chown to user_run where args may be flags and files/directories.
  def user_run_chmod( *args )
    flags, paths = args.partition { |a| a =~ /^-/ }
    sudo( 'chown', flags, "#{user_run}:#{user_run_group}", paths )
  end

  def user_exist?
    exec_conditional { run "id #{user_run}" } == 0
  end

  def user_create
    user_create! unless user_exist?
  end

  def user_create!
    sudo <<-SH
      useradd -g #{user_run_group} #{user_run}
    SH
  end

end
