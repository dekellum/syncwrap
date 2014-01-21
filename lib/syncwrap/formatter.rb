#--
# Copyright (c) 2011-2014 David Kellum
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

    attr_reader :io
    attr_reader :lock

    def initialize( io = $stdout )
      @io = io
      @lock = Mutex.new
    end

    def sync( &block )
      @lock.synchronize( &block )
    end

    def write_component( host, comp, method, state="begin" )
      io.puts clr.yellow( "== #{host.name} #{short_cn( comp.class )} " +
                          "#{method}: #{state}" )
      io.flush
    end
    def write_header( host, mode, opts )
      olist = []
      olist << "-#{opts[:sh_verbose]}" if opts[:sh_verbose] && mode != :rsync
      olist << 'coalesce' if opts[:coalesce] && mode != :rsync
      olist << "accept:#{opts[:accept].join ','}" if opts[:accept]
      olist << "user:#{opts[:user]}" if opts[:user]

      io.puts clr.yellow( "--- #{mode} #{host.name} (#{olist.join ' '})" )
      io.flush
    end

    def write_result( result )
      io.puts clr.yellow( result )
      io.flush
    end

    def write_command_outputs( outputs )
      newlined = true
      outputs.each do |stream, buff|
        newlined = write_command_output( stream, buff )
      end
      io.puts unless newlined
      io.flush
    end

    def write_command_output( stream, buff )
      case( stream )
      when :out, :cmd
        io.write buff
      when :err
        io.write clr.red
        io.write buff
        io.write clr.clear
      end
      ( buff[-1] == "\n" )
    end

     def clr
       Term::ANSIColor
     end

     def short_cn( cls )
       cls.name.sub(/^SyncWrap::/,'')
     end

  end

end
