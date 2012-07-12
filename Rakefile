# -*- ruby -*-

require 'rubygems'
require 'bundler/setup'

require 'rjack-tarpit'

RJack::TarPit.new( 'syncwrap' ).define_tasks

require 'syncwrap/java'
require 'syncwrap/hashdot'
require 'syncwrap/jruby'
require 'syncwrap/iyyov'
require 'syncwrap/ubuntu'
require 'syncwrap/postgresql'
require 'syncwrap/remote_task'

class Generator
  include Rake::DSL
  include SyncWrap::Java
  include SyncWrap::Hashdot
  include SyncWrap::JRuby

  include SyncWrap::UserRun
  include SyncWrap::Iyyov

  include SyncWrap::Ubuntu
  include SyncWrap::PostgreSQL

  include SyncWrap::RemoteTask

  def initialize
    super

    # SETUP: Install user, server instance goes here
    set :domain, "localhost"

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

Generator.new.define_tasks
