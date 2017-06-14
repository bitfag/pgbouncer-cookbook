include_recipe "postgresql::server"
include_recipe "postgresql::config_pgtune"
include_recipe 'database::postgresql'
include_recipe 'pgbouncer'

# user: foo, pass: bar
dbname = 'foo'
pass = 'md596948aad3fcae80c08a35c9b5958cd89'

postgresql_connection_info = {
    :host     => '127.0.0.1',
    :port     => node['postgresql']['config']['port'],
    :username => 'postgres',
    :password => node['postgresql']['password']['postgres']
}

postgresql_database_user dbname do
    connection postgresql_connection_info
    password pass
    action :create
end

postgresql_database dbname do
    connection postgresql_connection_info
    owner dbname
    action :create
end

postgresql_database_user dbname do
    connection postgresql_connection_info
    database_name dbname
    privileges [:all]
    action :grant
end

# create pgbouncer user
postgresql_database_user 'pgbouncer' do
    connection postgresql_connection_info
    password 'md5be5544d3807b54dd0637f2439ecb03b9'
    superuser true
    action :create
end

pgbouncer_connection 'local' do
  db_host 'localhost'
  db_port '5432'
  listen_port '6432'
  use_db_fallback true
  auth_user 'pgbouncer'
  admin_users ['foo']
  userlist 'pgbouncer' => 'md5be5544d3807b54dd0637f2439ecb03b9', 'foo' => pass
  log_connections 0
  log_disconnections 0
  action [ :setup, :start ]
end
