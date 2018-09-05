#--
# Copyright (c) 2011-2018 David Kellum
#
# Licensed under the Apache License, Version 2.0 (the "License"); you
# may not use this file except in compliance with the License.  You
# may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.  See the License for the specific language governing
# permissions and limitations under the License.
#++

require 'thread'
require 'term/ansicolor'

module SyncWrap

  class Formatter
    include Term::ANSIColor

    attr_reader :io
    attr_reader :lock
    attr_accessor :colorize

    def initialize( io = $stdout )
      @io = io
      @lock = Mutex.new
      @colorize = true
      @newlined = true
      @backtraces = {}
    end

    def sync( &block )
      @lock.synchronize( &block )
    end

    def write_component( host, comp, mth, state )
      io << yellow if colorize
      io << '== ' << host.name << ' ' << comp.class << '#' << mth
      io << ': ' << state
      io << clear if colorize
      io << "\n"
      flush
    end

    def write_header( host, mode, opts, live = false )
      olist = []
      olist << "-#{opts[:sh_verbose]}" if opts[:sh_verbose] && mode != :rsync
      olist << 'coalesce' if opts[:coalesce]
      olist << 'dryrun' if opts[:dryrun]
      olist << "accept:#{opts[:accept].join ','}" if opts[:accept]
      olist << "user:#{opts[:user]}" if opts[:user]
      olist << 'live' if live

      io << yellow if colorize
      io << '<-- ' << mode << ' ' << host.name
      first = true
      olist.each do |li|
        if first
          io << ' ('
          first = false
        else
          io << ' '
        end
        io << li
      end
      io << ')' unless olist.empty?
      io << clear if colorize
      io << "\n"
      flush
    end

    def write_result( result )
      io << yellow if colorize
      io << '--> ' << result
      io << clear if colorize
      io << "\n"
      flush
    end

    def write_command_outputs( outputs, color = true )
      outputs.each do |stream, buff|
        write_command_output( stream, buff, color )
      end
      output_terminate
      flush
    end

    def output_terminate
      unless @newlined
        io.puts
        @newlined = true
      end
    end

    def write_command_output( stream, buff, color = true )
      unless buff.empty?
        if stream == :err && colorize && color
          io << red << buff << clear
        else
          io << buff
        end
        @newlined = ( buff[-1] == "\n" )
      end
    end

    def write_error( host, error, comp = nil, mth = nil )
      bt = error.backtrace
      bt_num = @backtraces[ bt ]
      if bt_num
        bt = nil
      else
        @backtraces[ bt ] = bt_num = @backtraces.length + 1
      end

      io << yellow if colorize
      io << '== ' << host.name << ' '
      io << comp.class << '#' << mth << ' ' if comp && mth
      io << "error"
      io << ", same stack as" unless bt
      io << " [" << bt_num << "]:\n"

      io << red if colorize
      io << short_cn( error.class ) << ': ' << error.message << "\n"
      if bt
        bt.each do |line|
          break if line =~ /execute_component'$/
          io.puts line
        end
      end
      io << clear if colorize
      flush
    end

    def flush
      io.flush
    end

    def short_cn( cls )
      cls.name.sub(/^SyncWrap::/,'')
    end

  end

end
