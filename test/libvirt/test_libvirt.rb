#!/usr/bin/env ruby

#--
# Copyright (c) 2011-2015 David Kellum
#
# Licensed under the Apache License, Version 2.0 (the "License"); you
# may not use this file except in compliance with the License.  You
# may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.  See the License for the specific language governing
# permissions and limitations under the License.
#++

require 'rubygems'
require 'bundler/setup'

require 'minitest/unit'
require 'minitest/autorun'

require 'syncwrap'

# FIXME: These tests require a working test setup, some of which is not
# checked in for security reasons, i.e. private/*

class TestLibVirt < MiniTest::Unit::TestCase
  include SyncWrap

  SYNC_FILE = File.expand_path( '../sync.rb', __FILE__ )

  def setup
    @sp = Space.new
    @sp.load_sync_file_relative SYNC_FILE
  end

  def test_ubuntu_jruby
    with_profile( :ubuntu,
                  name: 'ubuntu-jruby-t',
                  add_roles: [:jruby] ) do |host|
      assert( @sp.execute( [ host ] ) )
      puts "[[ Test #{host.name} (again) ]]"
      assert( @sp.execute( [ host ] ) )
    end
    pass
  end

  def test_debian_jruby
    with_profile( :debian, name: 'deb-jruby-t', add_roles: [:jruby] ) do |host|
      assert( @sp.execute( [ host ] ) )
      puts "[[ Test #{host.name} (again) ]]"
      assert( @sp.execute( [ host ] ) )
    end
    pass
  end

  def test_centos_jruby
    with_profile( :centos, name: 'cent-jruby-t', add_roles: [:jruby] ) do |host|
      assert( @sp.execute( [ host ] ) )
      puts "[[ Test #{host.name} (again) ]]"
      assert( @sp.execute( [ host ] ) )
    end
    pass
  end

  def test_debian_postgres
    with_profile( :debian,
                  name: 'deb-pg-t',
                  add_roles: [:debian_postgres] ) do |host|
      assert( @sp.execute( [ host ] ) )
      puts "[[ Test #{host.name} (again) ]]"
      assert( @sp.execute( [ host ] ) )
    end
    pass
  end

  def test_ubuntu_postgres
    with_profile( :ubuntu,
                  name: 'ubuntu-pg-t',
                  add_roles: [:ubuntu_postgres] ) do |host|
      assert( @sp.execute( [ host ] ) )
      puts "[[ Test #{host.name} (again) ]]"
      assert( @sp.execute( [ host ] ) )
    end
    pass
  end

  def test_centos_postgres
    with_profile( :centos,
                  name: 'cent-pg-t',
                  add_roles: [:centos_postgres] ) do |host|
      assert( @sp.execute( [ host ] ) )
      puts "[[ Test #{host.name} (again) ]]"
      assert( @sp.execute( [ host ] ) )
    end
    pass
  end

  def test_debian_cruby
    with_profile( :debian,
                  name: 'deb-cruby-t',
                  add_roles: [:cruby] ) do |host|
      assert( @sp.execute( [ host ] ) )
      puts "[[ Test #{host.name} (again) ]]"
      assert( @sp.execute( [ host ] ) )
    end
    pass
  end

  def test_ubuntu_cruby
    with_profile( :ubuntu,
                  name: 'ubuntu-cruby-t',
                  add_roles: [:cruby] ) do |host|
      assert( @sp.execute( [ host ] ) )
      puts "[[ Test #{host.name} (again) ]]"
      assert( @sp.execute( [ host ] ) )
    end
    pass
  end

  def test_centos_cruby
    with_profile( :centos,
                  name: 'cent-cruby-t',
                  add_roles: [:cruby] ) do |host|
      assert( @sp.execute( [ host ] ) )
      puts "[[ Test #{host.name} (again) ]]"
      assert( @sp.execute( [ host ] ) )
    end
    pass
  end

  def with_profile( profile, opts = {} )
    host_name = opts[:name] || profile.to_s.gsub( '_', '-' ) + '-t'
    puts "[[ Create #{host_name} host ]]"
    @sp.provider.create_hosts( 1, profile, host_name, SYNC_FILE ) do |host|
      add_roles = opts[:add_roles]
      host.add( *add_roles ) if add_roles
    end

    puts "[[ Test #{host_name} ]]"
    yield @sp.host( host_name )

    puts "[[ Delete #{host_name} host ]]"
    @sp.provider.terminate_hosts( [ host_name ], false, SYNC_FILE )
  end

end
