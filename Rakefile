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
require 'syncwrap/aws'
require 'syncwrap/postgresql'
require 'syncwrap/remote_task'
require 'syncwrap/geminabox'

class SyncWrapper
  include SyncWrap::Java
  include SyncWrap::Hashdot
  include SyncWrap::JRuby
  include SyncWrap::Iyyov
  include SyncWrap::RHEL
  include SyncWrap::AWS
  include SyncWrap::PostgreSQL
  include SyncWrap::Geminabox

  include SyncWrap::RemoteTask

  def initialize
    super

    # SETUP: Install user@server instance goes here
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

    desc "Deploy Geminabox Daemon"
    remote_task :geminabox_deploy do
      iyyov_install_jobs do
        geminabox_install
      end
    end

    desc "Deploy PostgreSQL"
    remote_task :pg_deploy do
      pg_install
      pg_configure
      pg_start
    end

  end

end

SyncWrapper.new.define_tasks
