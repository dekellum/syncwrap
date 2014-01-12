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

# Provision a user to run daemons within a run directory. Utilities
# for working with the same.
class SyncWrap::RunUser < SyncWrap::Component

  # A user for running deployed daemons, jobs (default: 'runr')
  attr_accessor :run_user

  # A group for running (default: 'runr')
  attr_accessor :run_group

  # Root directory for persistent data and logs. (default: /var/local/runr)
  attr_accessor :run_dir

  def initialize( opts = {} )
    @run_user    = 'runr'
    @run_group   = 'runr'
    @run_dir = '/var/local/runr'
    super
  end

  def install
    create_user
    create_run_dir
  end

  # Create run_user if not already present
  def create_user
    sudo <<-SH
      if ! id #{run_user} >/dev/null 2>&1; then
        groupadd -f #{run_group}
        useradd -g #{run_group} #{run_user}
      fi
    SH
  end

  # Create and set owner/permission of run_dir, such that run_user may
  # create new directories there.
  def create_run_dir
    sudo <<-SH
      mkdir -p #{run_dir}
      chown #{run_user}:#{run_group} #{run_dir}
      chmod 775 #{run_dir}
    SH
  end

  def service_dir( sname, instance = nil )
    run_dir + '/' + [ sname, instance ].compact.join( '-' )
  end

  # Create and set owner/permission of a named service directory under
  # run_dir.
  def create_service_dir( sname, instance = nil )
    sdir = service_dir( sname, instance )
    sudo <<-SH
      mkdir -p #{sdir}
      chown #{run_user}:#{run_group} #{sdir}
      chmod 775 #{sdir}
    SH
  end

  # Chown to user:run_group where args may be flags and files/directories.
  # FIXME: Use above or drop?
  def run_user_chown( *args )
    flags, paths = args.partition { |a| a =~ /^-/ }
    sudo( [ 'chown', flags, "#{run_user}:#{run_group}",
            paths ].flatten.compact.join( ' ' ) )
  end

end
