
class Greeter < SyncWrap::Component
  def install
    say_it
  end

  def say_it
    sh <<-SH
      echo "Hello from #{host.name}"
    SH
  end
end

host 'localhost', Greeter.new
