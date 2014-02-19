# Important: Make this examples/sync directory first in
# sync_paths. This is not done by default, to make sure its explicit.
#
# The second path is the SyncWrap gems own sync directory.  The first
# path can effectively override any file that would otherwise be found
# in the second. This includes being able to override a static file
# with a template, or the other way around. This is what we mean by
# "transparent."
space.prepend_sync_path

class Writer < SyncWrap::Component
  attr_accessor :message

  def install
    rput( "tmp/sample" ) # implied destination --> /tmp/sample
  end
end

host 'localhost', Writer.new( message: "parameterized" )

# Try changing the message property above and running repeatedly in
# --verbose mode, to see how rsync uses checksums to detect
# changes. The cryptic looking output lines are actually returned as
# an array of changes from the rput call.
