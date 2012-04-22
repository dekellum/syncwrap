# -*- ruby -*-

#--
# Copyright (c) 2011-2012 David Kellum
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

desc "* Combined Java, HashDot, JRuby Deployment"
task :jruby_deploy => [ :java_install,
                        :hashdot_prereq,
                        :hashdot_install,
                        :hashdot_post_setup,
                        :jruby_install ]

desc "Install sun-java6-jdk from ferramroberto apt repo"
# http://www.gaggl.com/2011/10/installing-java6-jdk-on-ubuntu-11-10/
remote_task :java_install do
  sudo "add-apt-repository ppa:ferramroberto/java"
  sudo "apt-get update"
  sudo "apt-get -yq install sun-java6-jdk"
end

desc "Install hashdot apt prerequisites"
remote_task :hashdot_prereq do
  sudo "apt-get -yq install make gcc libapr1 libapr1-dev"
end

desc "Install hashdot from source tarball"
remote_task :hashdot_install do
  ver = '1.4.0'
  url = ( "http://downloads.sourceforge.net/project/hashdot/" +
          "hashdot/#{ver}/hashdot-#{ver}-src.tar.gz" )
  src_root = '/home/ubuntu/src'
  hd_src = "#{src_root}/hashdot-#{ver}"

  run "mkdir -p #{src_root}"
  run "rm -rf #{hd_src}"
  run "curl -sSL #{url} | tar -C #{src_root} -zxf -"
  rput( '-C', 'src/hashdot/', "#{hd_src}/" )
  run "cd #{hd_src} && make"
  sudo "sh -c 'cd #{hd_src} && make install'"
end

desc "Post hashdot install wrapper binaries"
remote_task :hashdot_post_setup do
  rput( 'usr/local/bin/jgem', '/tmp/' )
  sudo "cp -f /tmp/jgem /usr/local/bin/jgem"
  sudo "chmod 775 /usr/local/bin/jgem"
end

desc "Install JRuby"
remote_task :jruby_install do
  ver = '1.6.7'
  url = ( "http://jruby.org.s3.amazonaws.com/downloads/#{ver}/" +
          "jruby-bin-#{ver}.tar.gz" )
  prefix = '/usr/local'
  root = "#{prefix}/lib/jruby"

  sudo "mkdir -p #{root}"
  sudo "mkdir -p #{root}/gems"
  sudo "sh -c 'curl -sSL #{url} | tar -C #{root} -zxf -'"
  sudo "sh -c 'cd #{root} && ln -sf jruby-#{ver} jruby'"
  sudo "sh -c 'cd #{prefix}/bin && ln -sf ../lib/jruby/jruby/bin/jirb .'"
end
