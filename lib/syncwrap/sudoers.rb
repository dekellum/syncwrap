#--
# Copyright (c) 2011-2017 David Kellum
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

module SyncWrap

  # Utility methods for generating sudoers.d config
  module Sudoers

    # Default paths array for sudoers secure_path (PATH setting)
    # Versus RHEL* this has /usr/local support.
    # Versus recent Ubuntu this is identical save '/snap/bin'
    SECURE_PATH = %w[ /usr/local/sbin
                      /usr/local/bin
                      /usr/sbin
                      /usr/bin
                      /sbin
                      /bin ].freeze

    private

    # Return an sh script, including 'shebang' preamble, to writing
    # the file /etc/sudoers.d/<user>
    def sudoers_d_script( user, opts = {} )
      "#!/bin/sh -e\n" + sudoers_d_commands( user, opts )
    end

    # Return sh command lines string for writing the file
    # /etc/sudoers.d/<user>
    def sudoers_d_commands( user, opts = {} )
      lines = sudoers_d_template( user, opts )
      sh  = [ "echo '#{lines.shift}'  > /etc/sudoers.d/#{user}" ]
      sh += lines.map do |l|
        "echo '#{l}' >> /etc/sudoers.d/#{user}"
      end
      sh << "chmod 440 /etc/sudoers.d/#{user}"
      sh.join( "\n" )
    end

    # Return /etc/sudoers.d/<users> compatible config lines for user
    # and possible options, as an array
    def sudoers_d_template( user, opts = {} )
      spath = opts[:secure_path] || SECURE_PATH
      spath = spath.join(':') if spath.is_a?( Array )

      [ "#{user} ALL=(ALL) NOPASSWD:ALL",
        "Defaults:#{user} !requiretty",
        "Defaults:#{user} always_set_home",  # Default only on RHEL*
        "Defaults:#{user} secure_path = #{spath}" ]
    end

  end

end
