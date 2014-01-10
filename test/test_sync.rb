#!/usr/bin/env jruby
#.hashdot.profile += jruby-shortlived

#--
# Copyright (c) 2011-2013 David Kellum
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

require 'syncwrap/shell'

module SyncWrap

  class Component
  end

  class Role

    attr_accessor :components

    def initialize
      @components = []
    end

  end

  class Host

    attr_accessor :roles

    def initialize( name )
      @name = name
      @roles = []
    end

    #FIXME: Allow hosts to take components direct?
    def components
      # @components ||= []
      # FIXME: Sum components in roles?
    end

  end

  class Space

    def initialize
      @roles = {}
      @hosts = {}
    end

    def role( name )
      @roles[ name ] ||= Role.new
    end

    def host( name )
      @hosts[ name ] ||= Host.new( name )
    end

  end

end

class TestSync < MiniTest::Unit::TestCase
  include SyncWrap

  class CompOne < Component
    def install
    end
  end

  class CompTwo < Component
    def install
    end
  end

  def test
    sp = Space.new
    localhost = sp.host( 'localhost' )
    testrole = sp.role( :test )
    testrole.components = [ CompOne.new, CompTwo.new ]
    localhost.roles << testrole

  end

end
