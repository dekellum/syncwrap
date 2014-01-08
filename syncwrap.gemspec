# -*- ruby -*-

gem 'rjack-tarpit', '~> 2.0'
require 'rjack-tarpit/spec'

RJack::TarPit.specify do |s|
  require 'syncwrap/base'

  s.version = SyncWrap::VERSION

  s.add_developer( 'David Kellum', 'dek-oss@gravitext.com' )

  s.depend 'minitest', '~> 4.7.4', :dev
  s.depend 'aws-sdk',  '~> 1.8.5', :dev
end
