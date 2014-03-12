# -*- ruby -*-

require 'rubygems'
require 'bundler/setup'

require 'rjack-tarpit'

RJack::TarPit.new( 'syncwrap' ).define_tasks

desc "Upload RDOC to Amazon S3 (rdoc.gravitext.com/syncwrap, Oregon)"
task :publish_rdoc => [ :clean, :rerdoc ] do
  mime_types = {
    'html' => 'text/html; charset=utf-8',
    'css'  => 'text/css',
    'js'   => 'text/javascript',
    'png'  => 'image/png',
    'gif'  => 'image/gif'
  }
  mime_types.each do |ext,mime_type|
    sh <<-SH
      s3cmd sync -P --exclude '*.*' --include '*.#{ext}' \
        -m '#{mime_type}' \
        doc/ s3://rdoc.gravitext.com/syncwrap/
    SH
  end
end
