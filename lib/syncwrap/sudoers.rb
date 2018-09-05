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

module SyncWrap

  # Utility methods for generating sudoers.d config
  module Sudoers

    # Default paths array for sudoers secure_path (PATH setting) As
    # compared with RHEL derivatives this has /usr/local support and
    # retains /bin for distro's like Debian that have kept those
    # separate.  As compared with recent Ubuntu, this is the same
    # other than avoiding '/snap/bin'.
    SECURE_PATH = %w[ /usr/local/sbin
                      /usr/local/bin
                      /usr/sbin
                      /usr/bin
                      /sbin
                      /bin ].freeze

    protected

    # Return an sh script, including 'shebang' preamble, for writing
    # the file /etc/sudoers.d/<user>
    def sudoers_d_script( user, opts = {} )
      "#!/bin/sh -e\n" + sudoers_d_commands( user, opts )
    end

    # Return sh command lines string for writing the file
    # /etc/sudoers.d/<user>
    def sudoers_d_commands( user, opts = {} )
      sh = []
      sh << "cat > /etc/sudoers.d/#{user} <<_CONF_"
      sh += sudoers_d_template( user, opts )
      sh << "_CONF_"
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
