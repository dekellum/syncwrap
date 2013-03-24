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

require 'syncwrap/common'

# Provisions a JDK via an HTTP accessable binary repository of your
# making.  Sun/Oracle JDK usage terms generally preclude sharing a
# binary repository for these.
module SyncWrap::Java
  include SyncWrap::Common

  # HTTP URL to repo base directory. Note that the default
  # (http://localhost/repo) is unlikely to work here.
  attr_accessor :java_repo_base_url

  # The name of the JDK, which is used for download via
  # java_repo_base_url/<name>.tar.gz and the expected top level
  # directory when unpackaged.
  attr_accessor :java_jdk_name

  def initialize
    super

    @java_repo_base_url = 'http://localhost/repo'
    @java_jdk_name = 'jdk-ora-1.7.0_07-x64'
  end

  def java_jdk_url
    File.join( @java_repo_base_url, @java_jdk_name + '.tar.gz' )
  end

  def java_install
    java_install! unless exist?( "#{common_prefix}/lib/#{java_jdk_name}" )
  end

  def java_install!
    bins = %w[ java jmap jstack jstat jps jinfo jhat javac ].
      map { |b| "../lib/java/bin/#{b}" }.
      join( ' ' )

    sudo <<-SH
      curl -sSL #{java_jdk_url} | tar -C #{common_prefix}/lib -zxf -
      cd #{common_prefix}/lib && ln -sfn #{java_jdk_name} java
      cd #{common_prefix}/bin && ln -sfn #{bins} .
    SH

  end
end
