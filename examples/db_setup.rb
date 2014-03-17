class MyDatabase < SyncWrap::Component
  def install
    %w[ bob joanne ].each { |u| pg_create_user( u ) }
  end

  def pg_create_user( user, flags=[] )
    sql_test = "SELECT count(*) FROM pg_user WHERE usename = '#{user}'"
    sh( <<-SH, user: 'postgres' )
      if [[ $(psql -tA -c "#{sql_test}") == "0" ]]; then
        createuser #{flags.join ' '} #{user}
      fi
    SH
  end
end

host 'localhost', MyDatabase.new
