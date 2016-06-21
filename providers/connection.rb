#
# Cookbook Name:: pgbouncer
# Provider:: connection
#
# Copyright 2010-2013, Whitepages Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'set'

def initialize(*args)
  super
  @action = :setup
end

action :start do
  service "pgbouncer-#{new_resource.db_alias}-start" do
    service_name "pgbouncer-#{new_resource.db_alias}" # this is to eliminate warnings around http://tickets.opscode.com/browse/CHEF-3694
    provider Chef::Provider::Service::Upstart
    action [:enable, :start, :reload]
  end
  new_resource.updated_by_last_action(true)
end

action :restart do
  service "pgbouncer-#{new_resource.db_alias}-restart" do
    service_name "pgbouncer-#{new_resource.db_alias}" # this is to eliminate warnings around http://tickets.opscode.com/browse/CHEF-3694
    provider Chef::Provider::Service::Upstart
    action [:enable, :restart]
  end
  new_resource.updated_by_last_action(true)
end

action :stop do
  service "pgbouncer-#{new_resource.db_alias}-stop" do
    service_name "pgbouncer-#{new_resource.db_alias}" # this is to eliminate warnings around http://tickets.opscode.com/browse/CHEF-3694
    provider Chef::Provider::Service::Upstart
    action :stop
  end
  new_resource.updated_by_last_action(true)
end

action :setup do

  group new_resource.group do

  end

  user new_resource.user do
    gid new_resource.group
    system true
  end

  # Add pgdg ppa to use fresh pgbouncer
  run_context.include_recipe 'apt'

  apt_repository 'pgdg' do
    uri 'http://apt.postgresql.org/pub/repos/apt'
    distribution "#{node['lsb']['codename']}-pgdg"
    components ['main']
    key 'https://www.postgresql.org/media/keys/ACCC4CF8.asc'
  end

  # install the pgbouncer package
  #
  package 'pgbouncer' do
    action [:install]
    options '-o Dpkg::Options::="--force-confold"'
  end

  service "pgbouncer-#{new_resource.db_alias}" do
    provider Chef::Provider::Service::Upstart
    supports :enable => true, :start => true, :restart => true, :reload => true
    action :nothing
  end

  # create the log, pid, db_sockets, /etc/pgbouncer, and application socket directories
  Set.new([
   new_resource.log_dir,
   new_resource.pid_dir,
   new_resource.socket_dir,
   ::File.expand_path(::File.join(new_resource.socket_dir, new_resource.db_alias)),
   '/etc/pgbouncer'
  ]).each do |dir|
    directory "#{new_resource.name}::#{dir}" do
      path dir
      action :create
      recursive true
      owner new_resource.user
      group new_resource.group
      mode 0775
    end
  end

  # build the userlist, pgbouncer.ini, upstart conf templates
  {
    "/etc/pgbouncer/userlist-#{new_resource.db_alias}.txt" => 'etc/pgbouncer/userlist.txt.erb',
    "/etc/pgbouncer/pgbouncer-#{new_resource.db_alias}.ini" => 'etc/pgbouncer/pgbouncer.ini.erb',
    "/etc/init/pgbouncer-#{new_resource.db_alias}.conf" => 'etc/init/pgbouncer.conf.erb'
  }.each do |key, source_template|
    ## We are setting destination_file to a duplicate of key because the hash
    ## key is frozen and immutable.
    destination_file = key.dup

    # to get variables, use `grep "^attribute" resources/connection.rb |cut -d' ' -f2 | sed -e "s/:\(.*\),/\1: new_resource.\1,/"`
    template destination_file do
      cookbook 'pgbouncer'
      source source_template
      owner new_resource.user
      group new_resource.group
      mode destination_file.include?('userlist') ? 0600 : 0644
      variables({
        db_alias: new_resource.db_alias,
        db_host: new_resource.db_host,
        db_port: new_resource.db_port,
        db_name: new_resource.db_name,
        use_db_fallback: new_resource.use_db_fallback,
        userlist: new_resource.userlist,
        auth_user: new_resource.auth_user,
        admin_users: new_resource.admin_users,
        stats_users: new_resource.stats_users,
        users: new_resource.users,
        listen_addr: new_resource.listen_addr,
        listen_port: new_resource.listen_port,
        user: new_resource.user,
        group: new_resource.group,
        log_dir: new_resource.log_dir,
        socket_dir: new_resource.socket_dir,
        pid_dir: new_resource.pid_dir,
        pool_mode: new_resource.pool_mode,
        max_client_conn: new_resource.max_client_conn,
        default_pool_size: new_resource.default_pool_size,
        min_pool_size: new_resource.min_pool_size,
        reserve_pool_size: new_resource.reserve_pool_size,
        server_idle_timeout: new_resource.server_idle_timeout,
        server_reset_query: new_resource.server_reset_query,
        connect_query: new_resource.connect_query,
        tcp_keepalive: new_resource.tcp_keepalive,
        tcp_keepidle: new_resource.tcp_keepidle,
        tcp_keepintvl: new_resource.tcp_keepintvl,
        server_check_query: new_resource.server_check_query,
        log_connections: new_resource.log_connections,
        log_disconnections: new_resource.log_disconnections,
        log_pooler_errors: new_resource.log_pooler_errors,
        server_lifetime: new_resource.server_lifetime,
        ignore_startup_parameters: new_resource.ignore_startup_parameters,
        server_check_delay: new_resource.server_check_delay,
        reserve_pool_timeout: new_resource.reserve_pool_timeout,
        soft_limit: new_resource.soft_limit,
        hard_limit: new_resource.hard_limit
      })
    end
  end

  template "/etc/logrotate.d/pgbouncer-#{new_resource.db_alias}" do
      cookbook 'pgbouncer'
      source 'etc/logrotate.d/pgbouncer-logrotate.d.erb'
      owner "root"
      group "root"
      mode "0644"
      variables({
        db_alias: new_resource.db_alias,
        log_dir: new_resource.log_dir,
        pid_dir: new_resource.pid_dir
      })
    end

  new_resource.updated_by_last_action(true)
end

action :teardown do

  { "/etc/pgbouncer/userlist-#{new_resource.db_alias}.txt" => 'etc/pgbouncer/userlist.txt.erb',
    "/etc/pgbouncer/pgbouncer-#{new_resource.db_alias}.ini" => 'etc/pgbouncer/pgbouncer.ini.erb',
    "/etc/init/pgbouncer-#{new_resource.db_alias}.conf" => 'etc/pgbouncer/pgbouncer.conf',
    "/etc/logrotate.d/pgbouncer-#{new_resource.db_alias}" => 'etc/logrotate.d/pgbouncer-logrotate.d'
  }.each do |destination_file, source_template|
    file destination_file do
      action :delete
    end
  end

  new_resource.updated_by_last_action(true)
end
