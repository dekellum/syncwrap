# -*- ruby -*-

require 'rubygems'
require 'bundler/setup'

require 'rake/remote_task'

set :sudo_flags,  %w[ -H ]

set :rsync_flags, %w[ -rlpcb -ii ]

# SETUP: Server instance goes here
set :domain, "localhost"

# See tasks in rakelib/*.rake

## Common support functions

# remote put [extra args], SRC..., [DEST]
def rput( *args )
  if args.length == 1
    abspath = "/" + args.first
  else
    abspath = args.pop
  end
  args << [ target_host, abspath ].join( ':' )
  args = args.flatten.compact
  rsync( *args )
end
