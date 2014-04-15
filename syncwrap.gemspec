# -*- ruby -*-

gem 'rjack-tarpit', '~> 2.1'
require 'rjack-tarpit/spec'

RJack::TarPit.specify do |s|
  require 'syncwrap/base'

  s.version = SyncWrap::VERSION

  s.add_developer( 'David Kellum', 'dek-oss@gravitext.com' )

  s.depend 'term-ansicolor', '~> 1.2.2'
  s.depend 'tins',           '~> 0.13.2' #constrain term-ansicolor

  s.depend 'aws-sdk',        '>= 1.34.0', '< 1.39'
  s.depend 'json',           '>= 1.7.1', '< 1.9' #constrain aws-sdk
  s.depend 'nokogiri',       '>= 1.5.9', '< 1.7' #constrain aws-sdk
  s.depend 'uuidtools',      '~> 2.1.3'          #constrain aws-sdk

  s.depend 'minitest', '~> 4.7.4', :dev
  s.depend 'rdoc',     '~> 4.0.1', :dev

  s.required_ruby_version = '>= 1.9.1'
  s.extra_rdoc_files |= %w[ README.rdoc History.rdoc examples/LAYOUT.rdoc ]
end
