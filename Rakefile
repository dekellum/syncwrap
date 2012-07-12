# -*- ruby -*-

require 'rubygems'
require 'bundler/setup'

$LOAD_PATH.unshift( 'lib' )

require 'syncwrap/java'
require 'syncwrap/hashdot'
require 'syncwrap/jruby'
require 'syncwrap/iyyov'
require 'syncwrap/ubuntu'
require 'syncwrap/remote_task'

class Generator
  include Rake::DSL
  include SyncWrap::Java
  include SyncWrap::Hashdot
  include SyncWrap::JRuby

  include SyncWrap::UserRun
  include SyncWrap::Iyyov

  include SyncWrap::Ubuntu
  include SyncWrap::RemoteTask

  def initialize
    super

    # SETUP: Install user, server instance goes here
    set :domain, "localhost"

  end

  def generate

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

  end

end

Generator.new.generate
