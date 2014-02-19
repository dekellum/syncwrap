
class GreetSupport < SyncWrap::Component

  def install
    # provision "echo" support, if that were needed.
  end

  def say( msg )
    sh "echo '#{msg}'"
  end

end

class Greeter < SyncWrap::Component

  def install
    say "Hello from #{host.name}"
  end

end

host 'localhost', GreetSupport.new, Greeter.new

# When executing in the context of localhost, this Greeter has access
# to the public instance methods of this GreetSupport. The reverse is
# not true: this GreetSupport instance does not get any Greeter
# methods.
