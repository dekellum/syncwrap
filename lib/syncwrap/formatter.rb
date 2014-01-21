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
    include Term::ANSIColor

    attr_reader :io
    attr_reader :lock

    def initialize( io = $stdout )
      @io = io
      @lock = Mutex.new
      @newlined = true
    end

    def sync( &block )
      @lock.synchronize( &block )
    end

    def write_component( host, comp, method, state="start" )
      io.puts yellow( "== #{host.name} " +
                      "#{short_cn( comp.class )}##{method}: #{state}" )
      flush
    end

    def write_header( host, mode, opts, streaming = false )
      olist = []
      olist << "-#{opts[:sh_verbose]}" if opts[:sh_verbose] && mode != :rsync
      olist << 'coalesce' if opts[:coalesce]
      olist << 'dryrun' if opts[:dryrun]
      olist << "accept:#{opts[:accept].join ','}" if opts[:accept]
      olist << "user:#{opts[:user]}" if opts[:user]
      olist << "stream" if streaming

      io.puts yellow( "<-- #{mode} #{host.name} (#{olist.join ' '})" )
      flush
    end

    def write_result( result )
      io.puts yellow( "--> " + result )
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
        if stream == :err && color
          io.write red
          io.write buff
          io.write clear
        else
          io.write buff
        end
        @newlined = ( buff[-1] == "\n" )
      end
    end

    def flush
      io.flush
    end

    def short_cn( cls )
      cls.name.sub(/^SyncWrap::/,'')
    end

  end

end
