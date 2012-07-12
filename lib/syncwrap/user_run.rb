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

module SyncWrap::UserRun

  attr_accessor :user_run

  attr_accessor :user_run_group

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
