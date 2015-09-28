#--
# Copyright (c) 2011-2015 David Kellum
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

  # Support module for using a crytographic hash to verify the
  # integrity of a file, for example a downloaded package.
  module HashSupport

    protected

    # Enqueue a bash command to verify the specified file using the
    # given hash. This command will fail if the file does not
    # match. The hash :method can be specified in opts (i.e. :sha256)
    # or will be guessed from the provided hex-encoded hash string
    # length. Other opts are as per Component#sh, though options
    # accept, pipefail and error are ignored. Use of :user can allow
    # this command to be merged.
    def hash_verify( hash, file, opts = {} )
      opts = opts.dup
      mth = ( opts.delete(:method) || guess_hash_method( hash ) ) or
        raise( "Hash method unspecified and hash length " +
               "#{hash.length} is non-standard" )

      [ :accept, :pipefail, :error ].each { |k| opts.delete( k ) }

      sh( <<-SH, opts )
        echo "#{hash}  #{file}" | /usr/bin/#{mth}sum -c -
      SH
    end

    def guess_hash_method( hash )
      case hash.length
      when 32
        :md5
      when 40
        :sha1
      when 56
        :sha224
      when 64
        :sha256
      when 96
        :sha384
      when 128
        :sha512
      end
    end

  end

end
