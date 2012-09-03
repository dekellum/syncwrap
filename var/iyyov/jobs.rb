Iyyov.context do |c|

  c.base_dir = '/var/local/runr'

  c.define_daemon do |d|
    d.name     = "boxed-geminabox"
    d.version  = "~> 1.0.0"
    d.log_rotate
  end

end
