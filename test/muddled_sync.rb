
# This contrived sync file demonstrates evil method polution if loaded
# without the "wrap". See test_space_main.rb

include SyncWrap

# A method with name same as what IyyovDaemon#daemon_service_dir needs
# (and should be picked up via RunUser)
def service_dir( *args )
  raise "This is bad!"
end

host 'test', RunUser.new, IyyovDaemon.new
