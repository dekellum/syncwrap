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

    def rsync_args( host, srcs, target, opts = {} )

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
      ssh_flags = []
      ssh_flags += opts[ :ssh_flags ] if opts[ :ssh_flags ]
      if opts[ :ssh_user ]
        ssh_flags += [ '-l', opts[ :ssh_user ] ]
        ssh_flags += [ '-i', opts[ :ssh_user_pem ] ] if opts[ :ssh_user_pem ]
      end
      flags += [ '-e', "ssh #{ssh_flags.join ' '}" ] unless ssh_flags.empty?

      if opts[ :user ]
        # Use sudo to place files at remote.
        user = opts[ :user ].to_s
        flags << ( if user != 'root'
                     "--rsync-path=sudo -u #{user} rsync"
                   else
                     "--rsync-path=sudo rsync"
                   end )
      end

      #FIXME: Switch default to -E --executability ?
      if opts[ :perms ] && opts[ :perms ].is_a?( String )
        flags << "--chmod=#{opts[ :perms ]}"
      end

      excludes = Array( opts[ :excludes ] )
      flags += excludes.map do |e|
        if e == :dev
          '--cvs-exclude'
        else
          "--exclude=#{e}"
        end
      end

      flags << '-n' if opts[ :dryrun ]

      #FIXME: Add similar support for localhost, test in sudo case?

      [ 'rsync', flags, srcs, [ host, target ].join(':') ].flatten.compact
    end

    def expand_implied_target( srcs )
      #FIXME: Honor absolute arg paths?
      if srcs.length == 1
        target = "/" + srcs.first
        target = File.dirname( target ) + '/' unless target =~ %r{/$}
      else
        target = srcs.pop
      end
      [ srcs, target ]
    end

    # Preserves any trailing '/'.
    def resolve_sources( args, src_roots )
      #FIXME: Honor absolute arg paths?
      args.map do |path|
        path = path.strip
        found = src_roots.
          map { |r| File.join( r, path ) }.
          find { |src| File.exist?( src ) }
        # File.exist? only matches directories when trailing '/' is found.
        unless found
          raise SourceNotFound,
                "#{path.inspect} not found in roots #{src_roots.inspect}"
        end
        relativize( found )
      end
    end

    # Return path relative to PWD if the result is shorter, otherwise
    # return input path. Preserves any trailing '/'.
    def relativize( path )
      p = Pathname.new( path )
      unless p.relative?
        p = p.relative_path_from( Pathname.pwd ).to_s
        p += '/' if path[-1] == '/'
        path = p if p.length < path.length
      end
      path
    end

    def find_source_erbs( sources )
      Array( sources ).inject([]) do |list, src|
        if File.directory?( src )
          list += find_source_erbs( expand_entries( src ) )
        elsif src =~ /\.erb$/
          list << src
        end
        list
      end
    end

    def expand_entries( src )
      Dir.entries( src ).
        reject { |e| e =~ /^\.+$/ }.
        map { |e| File.join( src, e ) }
    end

  end

end
