#--
# Copyright (c) 2011-2014 David Kellum
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

begin
  require_relative 'options.rb'
rescue LoadError
  module TestOptions
    # Set true if local password-less sudo works
    SAFE_SUDO = false

    # Set to host name for safe (non-modifying) SSH tests
    SAFE_SSH = false

    # Set true if SAFE_SSH also supports pasword-less sudo
    SAFE_SSH_SUDO = false
  end
end