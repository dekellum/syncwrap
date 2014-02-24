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

require 'syncwrap/context'

module SyncWrap

  # Base class and primary interface for component implementation.
  #
  # Much of the protected interface is ultimately delegated to a
  # _current_ Context (arranged via Context#with). Without this, many
  # of these methods will raise a ContextError.
  #
  # Components that require installation should implement a public
  # no-argument `install` method which performs the installation via
  # #rput, #sh et al. Complex installations can be broken into
  # multiple methods called from install. If these are public and
  # no-argument, they may also be called from the CLI or other
  # external integrating code for testing or short-circuit
  # operation. In general however, install should be fast enough to
  # repeat in complete form. All such methods should be idempotent.
  #
  # Components may expose other public no-argument methods for
  # external use which are not called via install. For example,
  # diagnostic methods or uninstall.
  #
  # Components may also expose public utility methods (with or without
  # arguments) that will be dynamically bound and may be used by
  # higher (later) component instances stacked on the same Host.
  class Component

    # Construct given options that are applied via same name setters
    # on self.
    def initialize( opts = {} )
      super()
      opts.each do |name,val|
        send( name.to_s + '=', val )
      end
    end

    protected

    # Return the Host of the current Context.
    def host
      ctx.host
    end

    # Enqueue a bash shell command or script fragment to be run on the
    # host of the current Context. Newlines in command are interpreted
    # as per bash. For example, it is common to use a here-document
    # for readability:
    #
    #   sh <<-SH
    #     if [ ! -e /var/#{fname} ]; then
    #       touch /var/#{fname}
    #     fi
    #   SH
    #   #=> nil
    #
    # If the current context host name is 'localhost' then the command
    # is executed locally, without ssh and any ssh options will not be
    # used.
    #
    # Returns nil.
    #
    # See also #flush, in particular for possible collateral
    # Exceptions.
    #
    # === Command Queue and Composition
    #
    # The provided options are enqueued along with the
    # command/fragment for deferred execution. If a subsequent call
    # uses the same options, then it is effectively joined using a
    # newline with the prior commands in the queue. If a subsequent
    # call changes options, than any current commands in the queue are
    # executed (via #flush) before the current command is enqueued
    # with the new options. It is possible for commands to be enqueued
    # and joined across multiple Components within the same Context.
    #
    # For example the following will be executed as a single composed
    # script fragment:
    #
    #   sh "if [! -e /var/foobar]; then"
    #   sh "  touch /var/foobar"
    #   sh "fi" #=> nil
    #
    # However the following will result in remote errors:
    #
    #   sh "if [! -e /var/foobar]; then"
    #   sudo "touch /var/foobar" #=> CommandFailure
    #   sh "fi"
    #
    # ...since the initial fragment on the line 1 is incomplete,
    # when it is flushed and executed, due to line 2 changing
    # options (to user:root).
    #
    # When composing more elaborate conditionals or loops via local
    # methods, it is better to use the block form of #sh with the
    # :close option, like so:
    #
    #   sh( "if [! -e /var/foobar]; then", close: "fi" ) do
    #     sudo "touch /var/foobar" #=> NestingError
    #   end
    #
    # While executing the block, #flush is _locked_.  The above fails
    # with a NestingError and accurate stack trace, without running
    # any potentially dangerous, incomplete bash fragments on the
    # remote side. Replace the call to sudo with sh above and the
    # composed single fragment will execute without error. The block
    # form may be nested to arbitrary depth.
    #
    # === Options
    #
    # :user::       Execute command via sudo as the specified user, for
    #               example: :root or "root". See also :ssh_user
    #
    # :sudo_flags:: Additional Array of arguments to sudo, if used
    #               (see :user) Default: []
    #
    # :ssh_flags:: Array of flags in addition to, or overridden by
    #              :ssh_options (-o), :ssh_user (-l) and :ssh_user_pem
    #              (-i).
    #
    # :ssh_options:: Hash of ssh option key, value strings.
    #
    # :ssh_user::   The ssh -l (login_name) flag.
    #
    # :ssh_user_pem:: The ssh -i (identity_file) flag.
    #
    # :dryrun::     Don't actually execute commands, via `bash -n` dry
    #               run mode. (default: false)
    #
    # :verbose::    Show STDOUT/STDERR from commands (default: false)
    #
    # :sh_verbose:: Option values :v (or true) and :x are passed as
    #               `bash -v` and `bash -x` respectively, in order to
    #               echo command lines, interleaved with any command
    #               output. In the :x case, command output will be
    #               post expanded. This option should generally be set
    #               even if :verbose if false, since it will still be
    #               useful to error output on a CommandFailure.
    #               Default: nil (but :v via Space.default_options)
    #
    # :coalesce::   Coalesce (or merge) STDOUT to STDERR either via ssh
    #               or bash, to avoid out-of-order verbose output (due
    #               to buffering/timing). STDERR is used to increase
    #               incremental output through ssh, which tends to
    #               buffer STDOUT.
    #               Default: false (but true via Space.default_options)
    #
    # :error::      Pass bash the -e option to terminate early on errors.
    #               Default: true
    #
    # :close::      An additional bash fragment to append after the
    #               provided shell command/fragment and block has been
    #               enqueued. See usage example above. Default: nil
    #
    # :accept::     An array of Integer exit codes that will be accepted,
    #               and not result in a CommandFailure being
    #               raised. Generally this is only used with
    #               #capture. Default: [0]
    #
    def sh( command, opts = {}, &block )
      ctx.sh( command, opts, &block )
    end

    # Equivalent to `sh( command, user: :root )`
    def sudo( command, opts = {}, &block )
      sh( command, { user: :root }.merge( opts ), &block )
    end

    # Equivalent to `sh( command, user: run_user )` where run_user
    # would typically come from the RunUser component.
    def rudo( command, opts = {}, &block )
      sh( command, { user: run_user }.merge( opts ), &block )
    end

    # Capture and return [exit_code, stdout] from command, where
    # stdout is the entire stream read into a String. Any commands
    # already queued via #sh are executed via #flush beforehand, to
    # avoid ambiguous order of remote changes. Raises a CommandFailure
    # if the resulting exit_code is outside the specified :accept
    # option codes (by default, [0] only).
    #
    # Specify :coalesce if you want stderr merged with stdout in the
    # return. See #sh for additional options.  The options :coalesce,
    # and :dryrun are not inherited from the Space/Context default
    # options and must be explicitly passed.
    #
    # For the better performance achieved with larger script fragments
    # and fewer ssh sessions, you should attempt to use #sh remote
    # conditionals instead of testing with #capture on the local
    # side. But sometimes this can't be easily avoided.
    def capture( command, opts = {} )
      ctx.capture( command, opts )
    end

    # Return true if the current Context is executing in dryrun mode,
    # as per the :dryrun default option or via the command line
    # --dryrun flag. This allows additional explicit testing and
    # handling of this mode when necessary.
    def dryrun?
      ctx.dryrun?
    end

    # Return true if :verbose is set in default options.
    def verbose?
      ctx.verbose?
    end

    # Return the path to the the specified src, as first found in the
    # :sync_paths option as per #rput, Source Resolution.  Return nil
    # if not found.  This allows optional, local behavior based on the
    # existance of optional sources.
    def find_source( src, opts = {} )
      ctx.find_source( src, opts )
    end

    # Execute and empty the queue of any previous commands added with
    # #sh or its variants.
    #
    # A CommandFailure is raised if commands return an exit_code that
    # is not accepted via the :accept option (by default,
    # non-zero). See #sh options :accept and :error.
    #
    # A NestingError is raised if called from within a #sh block.
    #
    # Returns nil.
    def flush
      ctx.flush
    end

    # Transfer files or entire directories to host, each resolved to a
    # source root directory, while transparently processing any ERB
    # (.erb) templates.
    #
    # === Arguments
    #
    #   rput( src..., dest, {options} )
    #   rput( src, {options} )
    #
    # A trailing hash is interpreted as options, see below.
    #
    # If there are two or more remaining arguments, the last is
    # interpreted as the remote destination, and should be an absolute
    # path.  If there is a single src argument, the destination is
    # implied by finding its base directory and prepending '/'. Thus
    # for example:
    #
    #   rput( 'etc/gemrc', user: :root )
    #
    # has an implied destination of: "/etc/". The src and destination
    # directories are interpreted as by `rsync`: glob patterns are
    # expanded and trailing '/' is significant.
    #
    # Each src is searched in :sync_paths. See Source Resolution
    # below.
    #
    # === Execution
    #
    # Before execution, any commands queued via #sh are flushed to
    # avoid ambiguous order of remote changes.
    #
    # If the current context host name is 'localhost' then perform a
    # local-only transfer. This is not via ssh, so ssh options are not
    # applicable. The :user option will still be applied as by local
    # `sudo`.
    #
    # On success, returns an array of format [ [change_code,
    # file_name] ] for files changed, as parsed from the rsync
    # --itemize-changes.
    #
    # Raises SourceNotFound is any src argument is not found (per
    # below). On rsync failure, raises a CommandFailure.
    #
    # === Source Resolution
    #
    # For each src path in arguments, interpret each as a relative path
    # from any of the provided :sync_paths (see in Options below),
    # searched in order. The first matching source found will be
    # used. If no source is found (or if sync_paths is not provided
    # or empty) then raise a SourceNotFound exception. Note that a src
    # trailing '/' is significant both to rsync itself and that only
    # source directories will be matched.
    #
    # If a src path does not have a trailing '/' or '.erb' suffix
    # already, if the non-suffixed file is not found within a given
    # sync_path; then '.erb' is appended and tested as well. Thus if a
    # src "foo.erb" is given, the template must exist. If instead
    # 'foo' is given, then 'foo.erb' will be processed, if and only
    # if, 'foo' does not already exist in a given sync_path. See ERB
    # processing below.
    #
    # === ERB processing
    #
    # By default, any source files with an '.erb' suffix will be
    # interpreted as ERB templates, processed locally, and transferred
    # to the destination "in place" but without the '.erb'
    # suffix. This applies both to individually referenced source files
    # (with or without '.erb' suffix, see above) and '.erb' suffixed
    # files nested at any level within a source directory.
    #
    # ERB templates are passed a custom binding which gives access to
    # this component's instance methods, including dynamic binding to
    # same host, prior component instance methods. Additional
    # variables may be passed via the :erb_vars option.
    #
    # See various options controlling ERB processing below.
    #
    # === Options
    #
    # :user::      Files should be owned on destination by a user other
    #              than installer (ex: 'root'). See also :ssh_user
    #
    # :ssh_flags:: Array of flags to ssh via rsync -e, in addition to
    #              or overridden by :ssh_options (-o), :ssh_user (-l)
    #              and :ssh_user_pem (-i).
    #
    # :ssh_options:: Hash of ssh option key, value strings.
    #
    # :ssh_user::  The ssh -l (login_name) flag.
    #
    # :ssh_user_pem:: The ssh -i (identity_file) flag.
    #
    # :dryrun::    Don't actually make any changes, but report files
    #              that would be changed. (default: false)
    #
    # :recursive:: Recurse into sub-directories (default: true)
    #
    # :links::     Recreate symlinks on the destination (default: true)
    #
    # :checksum::  Use MD5 to determine changes; not just size,time
    #              (default: true) This is more costly but gives a
    #              more accurate representation of real file changes.
    #
    # :backup::    Make backup files on remote (default: true)
    #
    # :excludes::  One or more rsync compatible `--exclude` values, or
    #              :dev which excludes common development tree
    #              droppings like '*~'. Note that if you exclude
    #              "*.erb" then you probably also want to pass
    #              `erb_process: false`
    #
    # :perms::     Permission handling. The default (:E) is as per the
    #              rsync `--executability` flag: Only local exec (or
    #              non-exec) state will be transferred to remote files
    #              (including those pre-existing). This is most
    #              compatible with the limited permission tracking of
    #              a (D)VCS like git. Follow with your own remote chmod
    #              commands for finer control.
    #
    #              If set to :p, use `rsync --perms` instead (which
    #              transfers all permission bits.)
    #
    #              If set to a String "VALUE", instead use
    #              `rsync --perms --chmod=VALUE`
    #
    # :sync_paths:: Array of one or more local directories in which to
    #               find source files.
    #               Effectively required.
    #
    # :verbose::   Output stdout/stderr from rsync (default: false)
    #
    # :erb_process:: If false, treat '.erb' suffixed files as normal
    #                files (default: true)
    #
    # :erb_mode::  The trim_mode options as documented in ERB::new
    #              (default: '<>' trim NEWLINE on /^<%...%>$/ lines)
    #
    # :erb_vars::  Hash of additional variable names/values to pass to
    #              ERBs. These names will override the default
    #              component binding.
    #
    # Note finally that the :coalesce option is explicitly ignored,
    # since separating rsync STDOUT/STDERR is required for parsing
    # changes correctly.
    def rput( *args )
      opts = args.last.is_a?( Hash ) && args.pop || {}
      opts = opts.dup
      opts[ :erb_binding ] = custom_binding( opts[ :erb_vars ] || {} )
      ctx.rput( *args, opts )
    end

    # Attempt to dynamically bind and delegate missing methods to
    # Components that were added before self to the same Host.
    def method_missing( meth, *args, &block )
      pc = prior_component
      if pc && pc.respond_to?( meth )
        pc.send( meth, *args, &block )
      else
        super
      end
    end

    # Include the same dynamically bound, earlier component methods
    # via hook to respond_to?
    def respond_to_missing?( meth, include_private = false )
      super || ( ( pc = prior_component ) && pc.respond_to?( meth ) )
    end

    private

    def ctx
      Context.current or raise "ctx called out of SyncWrap::Context"
    end

    # Return the prior (added before) component instance on the same
    # host, or nil if either not in context, or no such component.
    def prior_component
      ( lc = Context.current ) && lc.host.prior_component( self )
    end

    def custom_binding( extra_vars = {} )
      extra_vars.inject( clean_binding ) do |b,(k,v)|
        # Can't yet rely on ruby 2.1 Binding#local_variable_set, so
        # use this eval trick instead, to be able to set arbitrary value
        # types.
        ks = k.to_sym.to_s #for safety
        b.eval("#{ks}=nil; lambda { |v| #{ks}=v }").call(v)
        b
      end
    end

    def clean_binding
      Kernel.binding
    end

  end

end
