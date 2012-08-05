# -*- ruby -*-

require 'rubygems'
require 'bundler/setup'

require 'rjack-tarpit'

RJack::TarPit.new( 'syncwrap' ).define_tasks

require 'syncwrap/java'
require 'syncwrap/hashdot'
require 'syncwrap/jruby'
require 'syncwrap/iyyov'
require 'syncwrap/rhel'
require 'syncwrap/postgresql'
require 'syncwrap/remote_task'

class SyncWrapper
  include SyncWrap::Java
  include SyncWrap::Hashdot
  include SyncWrap::JRuby
  include SyncWrap::Iyyov
  include SyncWrap::RHEL
  include SyncWrap::PostgreSQL

  include SyncWrap::RemoteTask

  def initialize
    super

    # SETUP: Install user@server instance goes here
    set :domain, "ec2-user@ec2-54-245-8-146.us-west-2.compute.amazonaws.com"

    set :ssh_flags,   %w[ -i key.pem ]
    set :rsync_flags, [ '-e', "ssh -i key.pem" ] + %w[ -rlpcb -ii ]

    self.java_repo_base_url =
      'https://s3-us-west-2.amazonaws.com/repo.gravitext.com'
  end

  def define_tasks

    desc "Combined Java, Hashdot, JRuby Deployment"
    remote_task :jruby_deploy do
      java_install
      hashdot_install
      jruby_install
    end

    desc "Deploy Iyyov Deamon"
    remote_task :iyyov_deploy do
      user_run_dir_setup
      iyyov_install
    end

    desc "Deploy PostgreSQL"
    remote_task :pg_deploy do
      pg_install
      pg_stop
      pg_adjust_sysctl
      pg_configure
      pg_start
    end

  end

end

SyncWrapper.new.define_tasks
