# -*- mode: ruby -*-
# vi: set ft=ruby :
require 'yaml'

Vagrant.configure("2") do |config|

  default_flavor = 'small'
  default_image = 'trusty'

  # allow users to set their own environment
  # which effect the hiera hierarchy and the
  # cloud file that is used
  environment = ENV['env'] || 'vagrant-vbox'
  layout = ENV['layout'] || 'full'
  map = ENV['map'] || environment

  config.vm.provider :virtualbox do |vb, override|
    #vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
  end

  config.vm.provider "lxc" do |v, override|
    override.vm.box = "fgrehm/trusty64-lxc"
  end

  last_octet = 41
  env_data = YAML.load_file("environment/#{layout}.yaml")

  map_data = YAML.load_file("environment/#{map}.map.yaml")

  machines = {}
  env_data['resources'].each do |name, info|
    (1..info['number']).to_a.each do |idx|
      machines["#{name}#{idx}"] = info
    end
  end

  machines.each do |node_name, info|

    config.vm.define(node_name) do |config|

      config.vm.provider :virtualbox do |vb, override|
        image = info['image'] || default_image
        override.vm.box = map_data['image']['virtualbox'][image]

        flavor = info['flavor'] || default_flavor
        vb.memory = map_data['flavor'][flavor]['ram']
        vb.cpus = map_data['flavor'][flavor]['cpu']
      end

      config.vm.synced_folder("hiera/", '/etc/puppet/hiera/')
      config.vm.synced_folder("modules/", '/etc/puppet/modules/')
      config.vm.synced_folder("manifests/", '/etc/puppet/modules/rjil/manifests/')
      config.vm.synced_folder("files/", '/etc/puppet/modules/rjil/files/')
      config.vm.synced_folder("templates/", '/etc/puppet/modules/rjil/templates/')
      config.vm.synced_folder("lib/", '/etc/puppet/modules/rjil/lib/')
      config.vm.synced_folder(".", "/etc/puppet/manifests")

      # Currently when virtual machine comes up, it gets a 172 IP from
      # the internal DHCP of virtualbox, after the virtual machine comes up, the 
      # DHCP server is disabled and the below command is executed on the VM so that
      # it gets the IP from DHCP server on HTTPPROXY vm
      config.vm.provision 'shell', :inline =>
      'ifdown eth1;ifup eth1'
     # This is required because otherwise hiera files will not be referenced at all
      config.vm.provision 'shell', :inline =>
      'cp /etc/puppet/hiera/hiera.yaml /etc/puppet/'

      config.vm.host_name = "#{node_name}.domain.name"
      ['consul'].each do |x|
        config.vm.provision 'shell', :inline =>
        "[ -e '/etc/facter/facts.d/#{x}.txt' -o -n '#{ENV["#{x}_discovery_token"]}' ] || (echo 'No #{x} discovery token set. Bailing out. Use \". newtokens.sh\" to get tokens.' ; exit 1)"
        config.vm.provision 'shell', :inline =>
        "mkdir -p /etc/facter/facts.d; [ -e '/etc/facter/facts.d/#{x}.txt' ] && exit 0; echo #{x}_discovery_token=#{ENV["#{x}_discovery_token"]} > /etc/facter/facts.d/#{x}.txt"
        config.vm.provision 'shell', :inline =>
        "echo #{x}_gossip_encrypt=`echo #{ENV["#{x}_discovery_token"]}| cut -b 1-15 | base64` >> /etc/facter/facts.d/consul.txt"
      end

      config.vm.provision 'shell', :inline =>
      "echo env=#{environment} > /etc/facter/facts.d/env.txt"

      if ENV['http_proxy']
        config.vm.provision 'shell', :inline =>
        "echo \"Acquire::http { Proxy \\\"#{ENV['http_proxy']}\\\" }\" > /etc/apt/apt.conf.d/03proxy"
        config.vm.provision 'shell', :inline =>
        "echo http_proxy=#{ENV['http_proxy']} >> /etc/environment"
      end


      if ENV['https_proxy']
        config.vm.provision 'shell', :inline =>
        "echo https_proxy=#{ENV['https_proxy']} >> /etc/environment"
      end
      config.vm.provision 'shell', :inline =>
        "echo no_proxy='127.0.0.1,169.254.169.254,localhost,consul,jiocloud.com' >> /etc/environment"
      # run apt-get update and install pip
      unless ENV['NO_APT_GET_UPDATE'] == 'true'
        config.vm.provision 'shell', :inline =>
        'apt-get update; apt-get install -y git curl;'
      end

      # upgrade puppet
      if ENV['http_proxy']
        config.vm.provision 'shell', :inline =>
        "test -e puppet.deb && exit 0; release=$(lsb_release -cs);http_proxy=#{ENV['http_proxy']} wget -O puppet.deb http://apt.puppetlabs.com/puppetlabs-release-${release}.deb;dpkg -i puppet.deb;apt-get update;apt-get install -y puppet-common=3.6.2-1puppetlabs1"
      else
        config.vm.provision 'shell', :inline =>
        "test -e puppet.deb && exit 0; release=$(lsb_release -cs);wget -O puppet.deb http://apt.puppetlabs.com/puppetlabs-release-${release}.deb;dpkg -i puppet.deb;apt-get update;apt-get install -y puppet-common=3.6.2-1puppetlabs1"
      end
      config.vm.provision 'shell', :inline =>
      'puppet apply -e \'ini_setting { basemodulepath: path => "/etc/puppet/puppet.conf", section => main, setting => basemodulepath, value => "/etc/puppet/modules.overrides:/etc/puppet/modules" } ini_setting { default_manifest: path => "/etc/puppet/puppet.conf", section => main, setting => default_manifest, value => "/etc/puppet/manifests/site.pp" } ini_setting { disable_per_environment_manifest: path => "/etc/puppet/puppet.conf", section => main, setting => disable_per_environment_manifest, value => "true" }\''
      config.vm.provision 'shell', :inline =>
      'puppet apply --detailed-exitcodes --debug -e "include rjil::jiocloud"; if [[ $? = 1 || $? = 4 || $? = 6 ]]; then apt-get update; puppet apply --detailed-exitcodes --debug -e "include rjil::jiocloud"; fi'

 
      net_prefix = ENV['NET_PREFIX'] || "192.168.100.0"
      nic_adapter= ENV['NIC_ADAPTER'] || `echo "No environment variable NIC_ADAPTER, set the NIC_ADAPTER you want to place the VM";exit 100`
      if node_name == 'httpproxy1'
        config.vm.network  "private_network", :ip => "192.168.100.10", :netmask => "255.255.255.0", :name => nic_adapter, :adapter => 2
      else
        config.vm.network "private_network", :type => :dhcp, :name => nic_adapter, :adapter => 2
      end
    end
  end
end
