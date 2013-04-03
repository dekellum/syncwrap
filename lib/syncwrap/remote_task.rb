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

require 'rake/remote_task'

require 'syncwrap/base'
require 'syncwrap/common'

# Implements common remoting methods in terms of rake/remote_task (and
# thus Vlad compatible)
module SyncWrap::RemoteTask
  include SyncWrap::Common
  include Rake::DSL

  # Array of zero to many host_names (typically short) that were
  # extracted from the HOSTS environment variable if set.
  attr_reader :hosts

  # A common domain name for all hosts, used to make host_long_name if
  # specified (default: nil)
  attr_accessor :common_domain

  def initialize
    @common_domain = nil
    interpret_hosts_var
    super

    # Defaults:
    set( :sudo_flags, %w[ -H ] )
    set( :rsync_flags, %w[ -rlpcb -ii ] )

    load_hosts_from_aws_instances if defined? aws_instances
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

  # Return the target host name of the currently executing RemoteTask.
  # Raises a StandardError if executed out of that context.
  def target_host
    remote_task_current.target_host
  end

  # Return true if the current target_host or specified host is part
  # of the specified role.
  def host_in_role?( role, host = target_host )
    role_hosts = Rake::RemoteTask.roles[ role ]
    role_hosts && !!( role_hosts[ host ] )
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

  def interpret_hosts_var
    hvar, ENV[ 'HOSTS' ] = ENV[ 'HOSTS' ], nil
    @hosts = (hvar || '').strip.split( /\s+/ )
    @host_pattern = if @hosts.empty?
                      // #match all if none specified.
                    else
                      Regexp.new( '^((' + @hosts.join( ')|(' ) + '))$' )
                    end
  end

  # Forward to Rake::RemoteTask.host using the host_long_name, but
  # only if the specified host_name matches any host_pattern. The :all
  # role is automatically included for all hosts.  Note this need not
  # be manually provided int the Rakefile if aws_instances is provided
  # instead.
  def host( host_name, *roles )
    if host_name =~ @host_pattern
      Rake::RemoteTask.host( host_long_name( host_name ), :all, *roles )
    end
  end

  # Define a RemoteTask host from an inst hash as defined by the AWS
  # module. Override to change how instances are mapped to RemoteTask, host By
  # default, using host_long_name( inst[:name] )
  def host_from_instance( inst )
    host( inst[:name], inst[:roles] )
  end

  # Calls host_from_instance for all aws_instances.
  def load_hosts_from_aws_instances
    aws_instances.each do |inst|
      host_from_instance( inst )
    end
  end

  # Speculative override from AWS to automaticly set a host when added.
  # Will fail if used without AWS module as super receiver.
  def aws_instance_added( inst )
    super
    host_from_instance( inst )
  end

  # Forward to Rake::RemoteTask.role using the host_long_name, but only if
  # the specified host_name matches any host_pattern.
  def role( role_name, host_name = nil, args = {} )
    if host_name =~ @host_pattern
      Rake::RemoteTask.role( role_name, host_long_name( host_name ), args )
    end
  end

  def remote_task_current
    Thread.current[ :task ] or raise "Not running from a RemoteTask"
  end

  # Return a long name for the specified host_name (which may be
  # short).  This implementation adds common_domain if
  # specified. Otherwise host_name is returned unmodified.
  def host_long_name( host_name )
    if common_domain
      "#{host_name}.#{common_domain}"
    else
      host_name
    end
  end

  # Return a short name for the specified host_name (which may be long).
  def host_short_name( host_name )
    ( host_name =~ /^([a-z0-9\-]+)/ ) && $1
  end

end
