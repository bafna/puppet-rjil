#
# Class: rjil::ceph
#  Install and configure ceph on both ceph clients and servers
#
# == Parameters
#
# [*fsid*]
#   Ceph fsid - a unique id for the ceph cluster
#
# [*keyring*]
#   Path to ceph keyring file. Default: /etc/ceph/keyring
#
# [*auth_type*]
#   Ceph auth type. Cephx provide authentication managed by ceph mons. Default: Cephx
#
# [*storage_cluster_if*]
#   Network Interface used for storage cluster.
#
# [*storage_cluster_network*]
#   Optional storage cluster network. If not specified, auto detected from
#   ip address assigned to $storage_clsuter_if
#
# [*public_if*]
#   Network Interface used for public communication - this is the interface used
#   by storage clients for storage access.
#
# [*public_network*]
#   Optional public network. If not specified, automatically detected from ip
#   address assigned to $public_if
#
# [*osd_journal_type*]
#   OSD Jounal types. Valid types are
#     first_partition -> first partition of the data disk,
#     filesystem -> journal directory under individual disk filesystem,
#
# [*pool_default_size*]
#   Default number of replicas for all pools, unless override in any pools.
#   Default: 3, and it should be 3 or more in production systems.
#

class rjil::ceph (
  $fsid,
  $keyring                = '/etc/ceph/keyring',
  $auth_type              = 'cephx',
  $storage_cluster_if     = eth1,
  $storage_cluster_network= undef,
  $public_network         = undef,
  $public_if              = eth0,
  $osd_journal_type       = 'filesystem',
  $pool_default_size      = undef
) {

  anchor {'rjil::ceph::start':
    before => Class['::ceph::conf']
  }
  anchor {'rjil::ceph::end':
    require => Class['::ceph::conf']
  }

  #include ntp

  #Service[ntp] -> Package[ceph]

  if $storage_cluster_network {
    $storage_cluster_network_orig = $storage_cluster_network
  } elsif $storage_cluster_if {
    $sc_net   = inline_template("<%= scope.lookupvar('network_' + @storage_cluster_if) %>")
    $sc_mask  = inline_template("<%= scope.lookupvar('netmask_' + @storage_cluster_if) %>")
    if $sc_mask {
      $sc_cidr  = netmask2cidr($sc_mask)
      $storage_cluster_network_orig = "${sc_net}/${sc_cidr}"
    }
  }

  if $public_network {
    $public_network_orig = $public_network
  } elsif $public_if {
    $pub_net   = inline_template("<%= scope.lookupvar('network_' + @public_if) %>")
    $pub_mask  = inline_template("<%= scope.lookupvar('netmask_' + @public_if) %>")
    if $pub_mask {
      $pub_cidr  = netmask2cidr($pub_mask)
      $public_network_orig = "${pub_net}/${pub_cidr}"
    }
  }

  ## run base ceph installation and config  which is to be setup
  ## on all systems which need ceph to be called

  ## Create ceph configuration directory
  ## This should go to ::ceph class, will be moved
  ##     if not there in thier master

  file {'/etc/ceph':
    ensure => directory,
  }

  ## Generage basic ceph configuration
  ## This is required to be exist on both ceph servers and clients

  class { '::ceph::conf':
    fsid             => $fsid,
    auth_type        => $auth_type,
    cluster_network  => $storage_cluster_network_orig,
    public_network   => $public_network_orig,
    osd_journal_type => $osd_journal_type,
    pool_default_size=> $pool_default_size,
    require          => File['/etc/ceph'],
  }

  ## File for logrotate postrotate
  file { '/usr/local/bin/ceph-postrotate.sh':
    source => 'puppet:///modules/rjil/ceph-postrotate.sh',
    mode => '0755',
    owner => 'root',
    group => 'root'
  }

  ## File for logrotate postrotate
  file { '/usr/local/bin/dump-logs.py':
    source => 'puppet:///modules/rjil/dump-logs.py',
    mode => '0755',
    owner => 'root',
    group => 'root'
  }

  rjil::jiocloud::logrotate{'ceph':
    logfile       => '/var/log/ceph/*log',
    postrotate    => '/usr/local/bin/ceph-postrotate.sh',
    sharedscripts => true,
    missingok     => true,
  }
}
