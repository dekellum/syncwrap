#--
# Copyright (c) 2011-2016 David Kellum
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

include SyncWrap

role( :ruby, CRubyVM.new( ruby_version: "2.1.2" ) )

host( 'centos-1', RHEL.new,   Network.new, :ruby, internal_ip: '192.168.122.4' )
host( 'ubuntu-1', Ubuntu.new, Network.new, :ruby, internal_ip: '192.168.122.145' )
