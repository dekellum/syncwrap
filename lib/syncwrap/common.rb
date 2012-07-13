#--
# Copyright (c) 2011-2012 David Kellum
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

require 'syncwrap/base'

module SyncWrap::Common

  attr_accessor :common_prefix

  def initialize
    super

    @common_prefix = '/usr/local'
  end

  # Return true is remote file exists
  def exist?( file )
    exec_conditional { run "test -e #{file}" } == 0
  end

  # Put files or entire directories to remote.
  #
  #   rput( src..., dest, {options} )
  #   rput( src, {options} )
  #
  # A trailing hash is interpreted as options, see below.
  #
  # If there is two or more remaining arguments, the last is
  # interpreted as the remote destination.  If there is a single
  # remaining argument, the destination is implied by find its base
  # directory and prepending '/'. Thus for example:
  #
  #   rput( 'etc/gemrc', :user => 'root' )
  #
  # has an implied destination of: `/etc/`. The src and destination
  # are intrepreted as by rsync: glob patterns are expanded and
  # trailing '/' is significant.
  #
  # ==== Options
  # :user:: Files should be owned on destination by a user other than
  #         installer (ex: 'root') (implies sudo)
  # :perms:: Permissions to set for install files.
  # :excludes:: One or more rsync compatible --filter excludes, or
  #             :dev which excludes common developmoent tree dropping,
  #             like '*~'
  def rput( *args )
    opts = args.last.is_a?( Hash ) && args.pop || {}

    if args.length == 1
      abspath = "/" + args.first
      abspath = File.dirname( abspath ) + '/' unless abspath =~ %r{/$}
    else
      abspath = args.pop
    end

    flags = []

    excludes = Array( opts[ :excludes ] )
    flags += excludes.map do |e|
      if e == :dev
        '--cvs-exclude'
      else
        "--filter=#{e}"
      end
    end

    if opts[ :perms ]
      flags << '-p'
      flags << "--chmod=#{opts[ :perms ]}"
    end

    if opts[ :user ]
      # Use sudo to place files at remote.
      user = opts[ :user ] || 'root'
      flags << ( if user != 'root'
                   "--rsync-path=sudo -u #{user} rsync"
                 else
                   "--rsync-path=sudo rsync"
                 end )
    end

    cmd = [ flags, args, [ target_host, abspath ].join(':') ].flatten.compact
    rsync( *cmd )

  end

end
