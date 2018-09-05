#--
# Copyright (c) 2011-2018 David Kellum
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

require 'time'
require 'term/ansicolor'

require 'syncwrap/component'

module SyncWrap

  # Component for checking and comparing remote host times. This can
  # be used to validate proper time keeping (e.g. via ntpd or similar)
  # on multiple remote hosts by comparing with local time. Its also
  # illustrative of syncwrap threading and synchronized output
  # formatting.
  #
  # === Usage
  #
  # First you should add this component to some or all hosts:
  #
  #     role( :all, TimeChecker.new )
  #
  # Then you run it via the command line:
  #
  #     syncwrap TimeChecker.check
  #
  # You can also experiment with -v and -t flags if desired.
  #
  # Output is in the following form per host:
  #
  #     host-name : start-delta <- HH:MM:SS.NNNNNNZ -> return-delta
  #
  # Where:
  #
  # * the captured and parsed remote time is shown in 'Z'ulu (UTC)
  #
  # * start-delta is the time difference between the local time, just
  #   before the remote command is started, and the remote time.
  #
  # * return-delta is the difference between the remote time and local
  #   time, just after the remote command has returned.
  #
  # If both local and remote hosts have well synchronized clocks, then
  # both these differences should be positive, but small negative
  # values for return-delta are common, in the range of the clock
  # skew. Negative values are formatted in red when output is
  # colorized.
  #
  # Host component dependencies: none
  class TimeChecker < Component
    include Term::ANSIColor

    FORMAT = "%-24s: %s%9.6fs%s <- %s -> %s%9.6fs%s\n".freeze

    def check
      lnow1 = Time.now.utc
      rc, out = capture( 'date --rfc-3339=ns' )
      if rc == 0
        lnow2 = Time.now.utc
        rnow = Time.parse( out ).utc
        d1 =         rnow - lnow1
        d2 = lnow2 - rnow
        formatter.sync do
          c = formatter.io
          c << FORMAT % [ host.name,
                          d1 < 0.0 ? red? : green?, d1, clear?,
                          rnow.strftime( '%H:%M:%S.%6NZ' ),
                          d2 < 0.0 ? red? : green?, d2, clear? ]
          c.flush
        end
      end
    end

    private

    def formatter
      @formatter ||= host.space.formatter
    end

    def green?
      formatter.colorize ? green : ""
    end

    def red?
      formatter.colorize ? red : ""
    end

    def clear?
      formatter.colorize ? clear : ""
    end

  end

end
