# -*- ruby -*-

require 'rubygems'
require 'bundler/setup'

require 'rjack-tarpit'

RJack::TarPit.new( 'syncwrap' ).define_tasks

desc "Upload RDOC to Amazon S3 (rdoc.gravitext.com/syncwrap, Oregon)"
task :publish_rdoc => [ :clean, :rerdoc ] do
  sh <<-SH
    aws s3 sync --acl public-read doc/ s3://rdoc.gravitext.com/syncwrap/
  SH
end

task :rdoc do
  sh <<-SH
    rm -rf doc/fonts
    cp rdoc_css/*.css doc/css/
  SH
end
