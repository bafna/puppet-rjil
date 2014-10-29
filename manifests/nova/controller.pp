#
# Class: rjil::nova::controller
#   To setup nova controller
class rjil::nova::controller (
  $rpc_zmq_bind_address = '*',
  $rpc_zmq_contexts     = 1,
  $rpc_zmq_matchmaker   = 'oslo.messaging._drivers.matchmaker_ring.MatchMakerRing',
  $rpc_zmq_port         = 9501,
  $api_bind_port        = 8774,
  $vncproxy_bind_port   = 6080,
) {

# Tests
  include rjil::test::nova_controller

  ##
  # Adding service blocker for mysql which make sure mysql is avaiable before
  # database configuration.
  ##

  ensure_resource( 'rjil::service_blocker', 'mysql', {})
  Rjil::Service_blocker['mysql'] ->
  Nova_config<| title == 'database/connection' |>

  ##
  # db_sync fail if nova-manage.log is writable by nova user, so making the file
  # with appropriate ownership before setup database configuration.
  ##

  File['/var/log/nova/nova-manage.log'] ->
  Nova_config<| title == 'database/connection' |>

  ##
  # Add zmq specific configuration in case of zmq rpc_backend
  # Also make sure nova services refreshed on matchmakerring config changes.
  ##

  nova_config {
    'DEFAULT/rpc_zmq_bind_address': value => $rpc_zmq_bind_address;
    'DEFAULT/ring_file':            value => '/etc/oslo/matchmaker_ring.json';
    'DEFAULT/rpc_zmq_port':         value => $rpc_zmq_port;
    'DEFAULT/rpc_zmq_contexts':     value => $rpc_zmq_contexts;
    'DEFAULT/rpc_zmq_ipc_dir':      value => '/var/run/openstack';
    'DEFAULT/rpc_zmq_matchmaker':   value => $rpc_zmq_matchmaker;
    'DEFAULT/rpc_zmq_host':         value => $::hostname;
  }

  Matchmakerring_config<||> ~> Exec['post-nova_config']

  ##
  # python-six(1.8.x) is required which are not handled in the package.
  # So handling here.
  ##
  ensure_resource('package','python-six',{ensure => latest})

  Package['python-six'] -> Class['nova::api']


  include ::nova::client
  include ::nova
  include ::nova::scheduler
  include ::nova::api
  include ::nova::network::neutron
  include ::nova::conductor
  include ::nova::cert
  include ::nova::consoleauth
  include ::nova::vncproxy

  ##
  # Making sure /var/log/nova-manage.log is wriable by nova user. This is
  # because, nova module is running "nova-manage db sync" as user nova
  # which is failing as nova dont have write permission to nova-manage.log.
  ##

  ensure_resource('user','nova',{ensure => present})

  ensure_resource('file','/var/log/nova', {ensure => directory})

  file {'/var/log/nova/nova-manage.log':
    ensure  => file,
    owner   => 'nova',
  }

  ##
  # Consul service registration
  # nova api bind port is not there in nova::api class param, so adding that
  # param in rjil::nova::controller.
  ##

  rjil::jiocloud::consul::service {'nova':
    tags          => ['real'],
    port          => $api_bind_port,
    check_command => "/usr/lib/nagios/plugins/check_http -I ${::nova::api::api_bind_address} -p ${api_bind_port}"
  }

  rjil::jiocloud::consul::service {'nova-scheduler':
    port          => 0,
    check_command => "sudo nova-manage service list | grep 'nova-scheduler.*${::hostname}.*enabled.*:-)'"
  }

  rjil::jiocloud::consul::service {'nova-conductor':
    port          => 0,
    check_command => "sudo nova-manage service list | grep 'nova-conductor.*${::hostname}.*enabled.*:-)'"
  }

  rjil::jiocloud::consul::service {'nova-cert':
    port          => 0,
    check_command => "sudo nova-manage service list | grep 'nova-cert.*${::hostname}.*enabled.*:-)'"
  }

  rjil::jiocloud::consul::service {'nova-consoleauth':
    port          => 0,
    check_command => "sudo nova-manage service list | grep 'nova-consoleauth.*${::hostname}.*enabled.*:-)'"
  }

  rjil::jiocloud::consul::service {'nova-vncproxy':
    port          => $vncproxy_bind_port,
    tags          => ['real'],
    check_command => "/usr/lib/nagios/plugins/check_http -H localhost -p $vncproxy_bind_port -u /vnc_auto.html",
  }

}
