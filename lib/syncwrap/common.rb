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

  # Put (synchronize) files or entire directories to remote.
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
  # has an implied destination of: `/etc/`
  #
  # After interpreting args calls rsync, possibly followed by sudo
  # chown.
  #
  # ==== Options
  # :user:: Files should be owned on destination by a user other than
  #         installer (ex: 'root') (implies sudo)
  # :sudo:: If true, use 'sudo rsync' on remote side.
  # :perms:: Permissions to set for install files.
  # :excludes:: One or more rsync compatible --filter excludes, or
  #             :dev which excludes common developmoent tree dropping,
  #             like '*~'
  def rput( *args )
    opts = args.pop if args.last.is_a?( Hash )

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
        raise "Unsupported exclude [#{e}] with :user option" if opts[ :user ]
        "--filter=#{e}"
      end
    end

    if opts[ :perms ]
      flags << '-p'
      flags << "--chmod=#{opts[ :perms ]}"
    end

    if opts[ :user ] || opts[ :sudo ]
      # Use sudo is needed to place files at remote
      flags << '--rsync-path=sudo rsync'
    end

    cmd = [ flags, args, [ target_host, abspath ].join(':') ].flatten.compact
    rsync( *cmd )

    if opts[ :user ]
      dest_files = expand_local_paths( args )
      dest_files = dest_files.map do |df|
        File.join( abspath, df )
      end
      unless dest_files.empty?
        sudo "chown #{opts[ :user ]} #{dest_files.join(' ')}"
      end
    end

  end

  # Expand local source patterns in an rsync compatible way,
  # i.e. tailing '/' is signficant.
  def expand_local_paths( srcs )
    # Expand globs
    srcs = srcs.map do |src|
      s = Dir.glob( src )
      raise "Local rput source [#{src}] not found" if s.empty?
      s
    end.flatten

    # Expand, recursively
    srcs = srcs.map do |src|
      if src =~ %r{/$}
        expand( src, '' )
      elsif File.directory?( src )
        expand( src, File.basename( src ) )
      else
        File.basename( src )
      end
    end.flatten.sort.uniq

    # FIXME: Need general support for filters. Would be nice
    # to support filtering (local + rsync) by `git ls-files -o`
    # For now lets exclude the obvious case:
    srcs.reject { |src| src =~ /~$/ }
  end

  def expand( lpath, rpath )
    Dir.entries( lpath ).
      reject { |s| s =~ /^\.+$/ }.
      map do |e|
        apath = File.join( lpath, e )
        npath = File.join( rpath, e )
        if File.directory?( apath )
          [ npath, expand( apath, npath ) ]
        else
          npath
        end
      end
  end

end
