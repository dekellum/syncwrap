# Demonstrates provisioning a PostgreSQL instance on Amazon EC2.
#
# This includes a custom 4 EBS-volume software RAID-1+0 for the
# database storage.
#
# With API key-pair and pem (see SETUP below) create a host and
# provision it via:
#
#   syncwrap -C postgres:pg-1 -v
#
# The host (name 'pg-1') definition will be automaticly added to the
# end of this file.

include SyncWrap

# SETUP: edit the sample file for your API key-pair obtained via AWS console
space.use_provider( AmazonEC2, aws_config: 'private/aws.json' )

profile( :default,                  # The "default" profile
         image_id: "ami-ccf297fc",  # Amazon Linux 2013.09.2 EBS 64 us-west-2
         region: 'us-west-2',       # Oregon; or change region and ami.
         user_data: :ec2_user_sudo, # Sudoer ec2-user \w no-tty required
         key_name: 'sec',           # SETUP: Create this key in AWS console,
                                    # or rename to an existing key.
                                    # Same ssh_user_pem file below:
         roles: [ :amazon_linux ] )

profile( :postgres,                 # Inherits properties from :default
         instance_type: 'm1.small',
         ebs_volumes: 4,
         ebs_volume_options: { size: 2 }, #gb
         roles: [ :postgres ] )

role( :amazon_linux,
      Users.new( ssh_user: 'ec2-user',
                 ssh_user_pem: 'private/sec.pem' ), # SETUP
      RHEL.new,
      Network.new )

role( :postgres,
      MDRaid.new( raw_devices: 4, lvm_volumes: [ [1.0, '/pg'] ] ),
      PostgreSQL.new( pg_data_dir: '/pg/data' ) )

# Generated Hosts:
