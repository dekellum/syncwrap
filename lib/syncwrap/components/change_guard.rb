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
require 'syncwrap/component'
require 'syncwrap/change_key_listener'

module SyncWrap

  # Maintains a remote guard file to preserve change_key state across
  # any transient failures which might occur in subsequent components
  # up until a paired ChangeUnGuard.
  #
  # Components which rely on change key state (via ChangeKeyListener
  # mixin or otherwise) may loose state due to transient failure and
  # thus remain out-of-sync on subsequent runs. This is particularly
  # common during concurrent development of such components.
  #
  # Typical usage using SourceTree as the change producer and Bundle
  # as one of possibly several consumers:
  #
  #    role( :my_role,
  #          SourceTree.new( change_key: :src_key ),
  #          *ChangeGuard.new( change_key: :src_key ).wrap(
  #            Bundle.new( change_key: :src_key ),
  #            # ...
  #          ) )
  #
  # Host component dependencies:  RunUser, SourceTree?
  class ChangeGuard < SyncWrap::Component
    include SyncWrap::ChangeKeyListener

    # Convenience method for constructed an array of
    # [ ChangeGuard, *nested_components, ChangeUnGuard ].
    def wrap( *nested_components )
      [ self, *nested_components, ChangeUnGuard.new ]
    end

    # Remote path and file name to use as the guard file
    # (Default: SourceTree#remote_source_path + '.changed')
    attr_writer :change_guard_file

    def change_guard_file
      @change_guard_file || "#{remote_source_path}.changed"
    end

    def initialize( opts = {} )
      @change_guard_file = nil
      super
    end

    def install
      if change_key_changes?
        rudo <<-SH
          touch #{change_guard_file}
        SH
      else
        code,_ = capture( <<-SH, user: run_user, accept: [0,92] )
          if [ -f "#{change_guard_file}" ]; then
            exit 92
          fi
        SH
        if code == 92
          Array( change_key ).each do |key|
            state[ key ] ||= []
            state[ key ] << [ '*found', change_guard_file ]
          end
        end
      end
    end
  end

  # Removes ChangeGuard#change_guard_file, once all dependent
  # components have successfully executed.
  class ChangeUnGuard < SyncWrap::Component
    def install
      rudo <<-SH
        rm -f #{change_guard_file}
      SH
    end
  end

end
