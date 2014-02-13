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

require 'syncwrap/path_util'

module SyncWrap

  module Rsync
    include PathUtil

    private

    def rsync_args( host, srcs, target, opts = {} )

      # -i --itemize-changes, used for counting changed files
      flags = %w[ -i ]

      # -r --recursive
      flags << '-r' unless opts[:recursive] == false

      # -l --links (recreate symlinks on the destination)
      flags << '-l' unless opts[:links] == false

      # -p --perms (set destination to source permissions)
      # -E --executability (perserve execute only, default)
      if opts[:perms] != false
        if opts[:perms] == :p || opts[:perms].is_a?( String )
          flags << '-p'
          if opts[ :perms ].is_a?( String )
            flags << "--chmod=#{opts[ :perms ]}"
          end
        else
          flags << '-E'
        end
      end

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

      excludes = Array( opts[ :excludes ] )
      flags += excludes.map do |e|
        if e == :dev
          '--cvs-exclude'
        else
          "--exclude=#{e}"
        end
      end

      flags << '-n' if opts[ :dryrun ]

      target = [ host, target ].join(':') unless host == 'localhost'

      [ 'rsync', flags, srcs, target ].flatten.compact
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
    # Raises SourceNotFound if any not found.
    def resolve_sources( srcs, sync_paths )
      srcs.map { |path| resolve_source!( path, sync_paths ) }
    end

    # Preserves any trailing '/'.
    # Raises SourceNotFound if not found.
    def resolve_source!( path, sync_paths )
      resolve_source( path, sync_paths ) or
        raise( SourceNotFound,
              "#{path.inspect} not found in :sync_paths #{sync_paths.inspect}" )
    end

    # Preserves any trailing '/'.
    # Returns nil if not found.
    def resolve_source( path, sync_paths )
      #FIXME: Honor absolute arg paths?
      found = nil
      sync_paths.each do |r|
        candidate = File.join( r, path )
        if File.exist?( candidate )
          found = candidate
        elsif candidate !~ %r{(\.erb|/)$}
          candidate += '.erb'
          if File.exist?( candidate )
            found = candidate
          end
        end
        break if found
      end

      found && relativize( found )
    end

    # Given file path within src, return any sub-directory path needed
    # to reach file, or the empty string.  This is also src trailing
    # '/' aware.
    def subpath( src, file )
      src = src.sub( %r{/[^/]*$}, '' ) #remove trail slash or last element
      File.dirname( file ).sub( /^#{src}\/?/, '' )
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
