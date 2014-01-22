#--
# Copyright (c) 2011-2014 David Kellum
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

require 'pathname'

require 'syncwrap/base'
require 'syncwrap/shell'

module SyncWrap

  module Rsync

    private

    # Put files or entire directories to remote
    #
    #   rsync( host, src..., dest, {options} )
    #   rsync( host, src, {options} )
    #
    # A trailing hash is interpreted as options, see below.
    #
    # After the host, if there are two or more remaining arguments, the last is
    # interpreted as the remote destination.  If there is a single
    # remaining argument, the destination is implied by finding its base
    # directory and prepending '/'. Thus for example:
    #
    #   rsync( 'foohost', 'etc/gemrc', user: :root )
    #
    # has an implied destination of: `/etc/`. The src and destination
    # are intrepreted as by `rsync`: glob patterns are expanded and
    # trailing '/' is significant.
    #
    # On success, returns an array of format [ [change_code, file_name] ]
    # for files changed, as parsed from the rsync --itemize-changes to
    # standard out.
    #
    # On failure, raises CommandFailure.
    #
    # ==== Options
    #
    # :user::      Files should be owned on destination by a user other
    #              than installer (ex: 'root') (implies sudo)
    # :perms::     Permissions to set for synchronized files. If just true,
    #              use local permissions (-p). (default: true)
    # :ssh_flags:: Array of flags to give to ssh via rsync -e
    # :excludes::  One or more rsync compatible --filter excludes, or
    #              :dev which excludes common developmoent tree droppings
    #              like '*~'
    # :dryrun::    Don't actually make any changes (but report files that
    #              would be changed) (default: false)
    # :recursive:: Recurse into subdirectories (default: true)
    # :links::     Recreate symlinks on the destination (default: true)
    # :checksum::  Use MD5 to determine changes; not just size,time
    #              (default: true)
    # :backup::    Make backup files on remote (default: true)
    # :src_roots:: Array of one or more local directories in which to
    #              find source files.
    #
    # :verbose::   Output stdout/stderr from rsync (default: false)
    def rsync_args( host, *args )
      opts = args.last.is_a?( Hash ) && args.pop || {}

      if args.length == 1
        abspath = "/" + args.first
        abspath = File.dirname( abspath ) + '/' unless abspath =~ %r{/$}
      else
        abspath = args.pop
      end

      srcs = resolve_sources( args, Array( opts[ :src_roots ] ) )

      # -i --itemize-changes, used for counting changed files
      flags = %w[ -i ]

      # -r --recursive
      flags << '-r' unless opts[:recursive] == false

      # -l --links (recreate symlinks on the destination)
      flags << '-l' unless opts[:links] == false

      # -p --perms (set destination to source permissions)
      flags << '-p' unless opts[:perms] == false

      # -c --checksum (to determine changes; not just size,time)
      flags << '-c' unless opts[:checksum] == false

      # -b --backup (make backups)
      flags << '-b' unless opts[:backup] == false

      # Pass ssh options via -e (--rsh) flag
      flags += [ '-e', "ssh #{opts[:ssh_flags]}" ] if opts[:ssh_flags]

      if opts[ :user ]
        # Use sudo to place files at remote.
        user = opts[ :user ].to_s
        flags << ( if user != 'root'
                     "--rsync-path=sudo -u #{user} rsync"
                   else
                     "--rsync-path=sudo rsync"
                   end )
      end

      if opts[ :perms ] && opts[ :perms ].is_a?( String )
        flags << "--chmod=#{opts[ :perms ]}"
      end

      excludes = Array( opts[ :excludes ] )
      flags += excludes.map do |e|
        if e == :dev
          '--cvs-exclude'
        else
          "--filter=#{e}"
        end
      end

      flags << '-n' if opts[ :dryrun ]

      [ 'rsync', flags, srcs, [ host, abspath ].join(':') ].flatten.compact
    end

    def resolve_sources( args, src_roots )
      args.map do |path|
        path = path.strip
        found = src_roots.
          map { |r| File.join( r, path ) }.
          find { |src| File.exist?( src ) }
        if found
          relativize( found )
        else
          raise SourceNotFound,
                "#{path.inspect} not found in roots #{src_roots.inspect}"
        end
      end
    end

    def relativize( path )
      p = Pathname.new( path )
      unless p.relative?
        p = p.relative_path_from( Pathname.pwd ).to_s
        path = p if p.length < path.length
      end
      path
    end

  end

end
