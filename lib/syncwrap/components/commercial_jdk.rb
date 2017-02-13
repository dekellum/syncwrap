#--
# Copyright (c) 2011-2017 David Kellum
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

require 'syncwrap/component'
require 'syncwrap/hash_support'

module SyncWrap

  # Provision a Commmercial (i.e. Oracle) JDK or "Server JRE" (jrs_)
  # via an HTTP accessable binary repository of your making.
  # Commercial usage terms generally preclude sharing a public binary
  # repository for these.  Given the size, check-in or pushing from a
  # development workstation is likely also a bad idea, though not
  # difficult to implement.
  #
  # Oracle and Java are registered trademarks of Oracle and/or its
  # affiliates.
  #
  # Host component dependencies: <Distro>
  class CommercialJDK < Component
    include HashSupport

    # HTTP URL to repo base directory. Note that the default
    # (http://localhost/repo) is unlikely to work here.
    attr_accessor :java_repo_base_url

    # The name of the JDK, which is used for download via
    # java_repo_base_url/<name>.tar.gz and the expected top level
    # directory when unpackaged.
    attr_accessor :jdk_name

    # An optional cryptographic hash value (hexadecimal, some standard
    # length) to use for verifying the 'jdk_name.tar.gz' package.
    # Default: nil (no verification)
    attr_accessor :hash

    def initialize( opts = {} )
      @java_repo_base_url = 'http://localhost/repo'
      @jdk_name = 'jrs-ora-1.7.0_51-x64'
      @hash = nil
      super
    end

    # Complete URL to the jdk tarball within the java/binary repo
    def jdk_url
      File.join( @java_repo_base_url, @jdk_name + '.tar.gz' )
    end

    # Local jdk directory, within local_root, to be installed
    def jdk_dir
      "#{local_root}/lib/#{jdk_name}"
    end

    def install
      distro = "/tmp/#{jdk_name}.tar.gz"
      bins = %w[ java jmap jstack jstat jps jinfo jhat javac ].
        map { |b| "../lib/java/bin/#{b}" }.
        join( ' ' )

      sudo( "if [ ! -d #{jdk_dir} ]; then", close: "fi" ) do
        dist_install( 'curl', minimal: true, check_install: true )
        sudo <<-SH
          curl -sSL -o #{distro} #{jdk_url}
        SH

        hash_verify( hash, distro, user: :root ) if hash

        sudo <<-SH
          tar -C #{local_root}/lib -zxf #{distro}
          rm -f #{distro}
          cd #{local_root}/lib && ln -sfn #{jdk_name} java
          cd #{local_root}/bin && ln -sfn #{bins} .
        SH
      end
    end

  end

end
