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

  # Utility methods for generating scripts to pass as user data.
  module UserData

    private

    # Returns an sh script to allow no password, no tty sudo for a
    # specified user by writing a file to /etc/sudoers.d/<user>
    def no_tty_sudoer( user )
      script = <<-SH
        #!/bin/sh -e
        echo '#{user} ALL=(ALL) NOPASSWD:ALL'  > /etc/sudoers.d/#{user}
        echo 'Defaults:#{user} !requiretty'   >> /etc/sudoers.d/#{user}
        echo 'Defaults:#{user} always_set_home' >> /etc/sudoers.d/#{user}
        chmod 440 /etc/sudoers.d/#{user}
      SH
      script.split( "\n" ).map( &:strip ).join( "\n" )
    end

    module_function :no_tty_sudoer

  end

end
