# -*- ruby -*-

require 'rjack-tarpit/spec' if gem 'rjack-tarpit', '~> 2.1'

RJack::TarPit.specify do |s|
  require 'syncwrap/base'

  s.version = SyncWrap::VERSION

  s.add_developer( 'David Kellum', 'dek-oss@gravitext.com' )

  s.depend 'term-ansicolor', '>= 1.2.2', '< 1.5'
  s.depend 'tins',           '~> 1.13.2' #constrain term-ansicolor

  s.depend 'aws-sdk',        '~> 1.46'
  s.depend 'json',           '>= 1.7.1', '< 2.2' #constrain aws-sdk
  s.depend 'nokogiri',       '>= 1.5.9', '< 1.9' #constrain aws-sdk

  s.depend 'minitest', '~> 5.9.1', :dev
  s.depend 'rdoc',     '~> 4.3.0', :dev

  s.required_ruby_version = '>= 1.9.1'
  s.extra_rdoc_files |= %w[ README.rdoc History.rdoc examples/LAYOUT.rdoc ]
end
