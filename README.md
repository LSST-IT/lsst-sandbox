# LSST Sandbox
Automatic Deployment of LSST Systems

The whole puppet infrastructure rely on several github repos listed below:

 * LSST Sandbox: This current repo
    * https://github.com/LSST-IT/lsst-sandbox
 * LSST Hiera: Used to provide configurations for the puppet server to deploy machines.
    * https://github.com/LSST-IT/lsst-sandbox-hiera
 * External Node Classifier (ENC): This provides you with a software that allows you to dynamically assign roles and profiles to a given node plus parameters than can be used to customize the puppet module behavior.
    * https://github.com/LSST-IT/puppet-enc.git
 * Nodes Database: This repo host all the nodes definitions, plus all the roles, profiles, classes and parameters than will be assign to a given node.
    * https://github.com/LSST-IT/lsst-sandbox-nodes-database.git

To properly run this environment, please install the following requirements in the established numerical order:

**Requirements:**

   1. VirtualBox

   2. Vagrant.

   3. VirtualBox Guests Additions - This needs to be done through vagrant cli, as a vagrant plugin (please refer to section **vagrant-vbguest**)

To use this scripts you need first to start up the puppet master VM. The network configured within this scripts is 10.0.0.0/24. All nodes have already an IP assigned and based on those IPs the services are being configured.

**vagrant-vbguest**

In order to mount the hiera folder into the VM, you need to first install the VirtualBox Guest Additions. Go into the puppet-master directory and run:

      vagrant plugin install vagrant-vbguest

If you already have install the plugin, make sure it is in the latest version:

      vagrant plugin update vagrant-vbguest

**Directory Structure**

This is the proposed structure to work with Puppet code and the LSST Sandbox. 

      workspace/
      ├── itconf_l1ts
      │   ├── Puppetfile
      │   ├── README.md
      │   ├── environment.conf
      │   ├── hiera.yaml
      │   ├── manifests
      │   │   └── site.pp
      │   └── site
      │       ├── facts
      │       ├── profile
      │       └── role
      └── lsst_devops
          ├── README.md
          ├── nodes
          │   ├── Makefile
          │   ├── Vagrantfile
          │   └── designs
          └── puppet-master
              ├── Puppetconf.yaml
              ├── Vagrantfile
              └── provision-script.sh


The Puppetconf.yaml file into the puppet-master directory, gives you all the configuration required for the puppet master to work, below a brief overview of each one:

 * `hostname`: It must be the FQDN, and for the puppet master it must be: "gs-puppet-master.vm.dev.lsst.org"
 * `ip`: You can decide which IP give to your puppet master, however, if you change the Default IP, you need to also update your local hiera configuration, since all the nodes are pointing to the default IP. This should be done with services discovery, is someone figure how to do this, help is welcomed.
 * `memory`: Amount of RAM assigned to the VM, by default 1024
 * `cpu`: Amount of CPUs to be assigned to the VM, by default is 1
 * `puppet_environment`: Only for puppet code developers. This is the environment that is going to be used to mount the gitcode you have in the host machine into `/etc/puppetlabs/code/environment/<puppet-environment>`. So, if you are working on a particular branch in the puppet code repo, that branch name should be the one used on this variable. 
 * `gitcode_path`: Only for puppet code developers, this is the path, on the host machine, in where the puppet code is living, using the proposed file structure, this dir should be `"../../itconf_l1ts/"`
 * `shared_hiera`: This is a boolean to define wether you want to share a local/custom hiera directory or use the default configured from a repo
 * `shared_hiera_path`: In case `shared_hiera` is true, this variable is used to indicate the path to the hiera value you want to share into the puppet-master server.

The provisioning script now allows the usage of arguments for the script:

    -S: Indicates wether you want to share a hiera or not"
    -p: Puppet environment to be used"
    -i: IP assigned to this puppet master, added in the /etc/hosts"
    -m: Name of the module to be mounted"
    -M: Puppet environment in where this module will be mounted"

Tests done already by deploying the puppet master and the headerservice mounting the code from the outside.

There is a known issue with the puppet master and the VM, which prevent the machine to boot after it has been powered off for the very first time, just to be aware.

**puppet-master**

To start up a Puppet Master, go into puppet-master directory and execute vagrant up. The ip for the puppet master is 10.0.0.250. Hostname configured as puppet-master.dev.lsst.org.

      vagrant up

That is going to spawn up a new VM using Virtualbox as VM backend and vagrant to manage the VMs quickly. This process will finish with an already configured VM with all the LSST puppet scripts. The domain for this environment will be dev.lsst.org. That is important because the country tag being used by either Puppet and Telegraf will be dev.

If there is given branch from the puppet code that you would like to test, then make sure you have the right environment configured on the nodes' database.

      cd puppet-master
      vagrant ssh 
      sudo su -
      admin.py -l

The commands above will list all the nodes definitions configured in puppet. Depending on the host you want to work on, you may want to use a different environment. You can do that in 2 different ways, by modifying the CSV files in where all those definitions are, or by modifying the current DB (sqlite file). I would prefer the second options since is a temporary change.

Example: 

      admin.py -u --node-def ts-efd -a environment=IT_971_avillalobos

Note that the environments database is configured in hiera, this repo as of today, is using the same repo I'm using for the Chilean services, I try to keep everything in production, but is always safer to double check which environment is given to your node.

Note: Make sure r10k_hiera_org value is not set in hiera before running the puppet master, this is to allow using hiera values from vagrant.

If you destroy a node and wants to re-provision it. You should also clean the SSL keys stored in the puppet master. That's because when a node is registered with the puppet master, it self sign the provided certificate from the node, if you destroy the VM and create a new one with the exact same hostname, the node will create a different SSL certificate that will have conflicts in the puppet master, therefore, is safer to, every time you destroy a VM, clean its associated SSL key. In order to do so:

      cd puppet-master
      vagrant ssh 
      sudo su -
      puppet cert list -a # which will list all the already signed certificates
      puppet cert clean [<fqdn>]{1,N}

Example:

      puppet cert clean ts-efd-srv-01.vm.dev.lsst.org ts-efd-mgmt-01.vm.dev.lsst.org ts-efd-data-02.vm.dev.lsst.org ts-efd-data-01.vm.dev.lsst.org

**Nodes**

To start up a node, move to nodes directory, there is a directory called designs, in where different yaml files are created, each yaml file describes a cluster within the same network range, so be careful about the IPs used.

      nodes/
      ├── Makefile
      ├── Vagrantfile
      └── designs
         ├── Vagrant_all.yaml
         ├── Vagrant_efd.yaml
         └── Vagrant_monitoring.yaml

The Vagrant_all.yaml have several nodes described which you can start up individually. The content of each specific cluster definition may or may not be in the Vagrant_all.yaml file, however you need to make sure that there is no repeated IPs that may have conflicts when starting up, as well as the hostname.

The main goal of this repo, is to have a set of different designs that better fulfill a given requirement, each yaml file will have a desired design for an infrastructure, in such a way that you can design how your system will behave and vagrant plus puppet will orchestrate that for you.

**PODs**

***EFD***

If you want to start up the EFD, you can leverage the makefile under nodes to do so.

      make start_efd

To verify the cluster's status:

      make status_efd      

If all your nodes (or at least the node your are interested on) are running, you can connect to it using vagrant ssh.

Example:

      vagrant --design=designs/Vagrant_efd.yaml ssh ts-efd-srv-01

the current options for the EFD are:

      make start_efd
      make destroy_efd
      make halt_efd
      make reload_efd
      make status_efd

***Monitoring Cluster***

If you want to start up the Monitoring, you can leverage the makefile under nodes to do so.

      make start_monitoring

To verify the cluster's status:

      make status_monitoring

If all your nodes (or at least the node your are interested on) are running, you can connect to it using vagrant ssh.

Example:

      vagrant --design=designs/Vagrant_monitoring.yaml ssh ts-grafana-node-01

the current options for the Monitoring are:

      make start_monitoring
      make destroy_monitoring
      make halt_monitoring
      make reload_monitoring
      make status_monitoring

***General***

There are more other definitions in the Vagrant_all.yaml that you can explore. If you want to start up any of those, you can do:

      vagrant up <VM name>

To connect:

      vagrant ssh <VM Name>

The vm name is the key of the yaml file that describes the VM.
