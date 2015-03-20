include SyncWrap

role( :all,
      Users.new )

role( :jruby,
      OpenJDK.new,
      JRubyVM.new( jruby_version: '1.7.19' ),
      Hashdot.new )

host( 'centos-1', RHEL.new, :jruby, internal_ip: '192.168.122.4' )
