---
authors:
- sara
title: Trace a paquet path within Kubernetes cluster 
date: 2024-05-17
tags:
- Kubernetes
- Networking
- Container
- CNI
images:
- xxx.png
codespace: https://codespaces.new/fence-io/playground
slug: "kubernetes-Networking"
series: 
- Networking
series_order: 1
series_opened: true
---

# Introduction

Tracing the path of network traffic in Kubernetes. Starting from the initial web request and down to the container hosting the application.

in this article you've learned in this article:

How containers talk locally or Intra-Pod communication.
Pod-to-Pod communication when the pods are on the same and different nodes.
Pod-to-Service - when pod sends traffic to another pod behind a service in Kubernetes.
What are namespaces, veth, iptables, chains, conntrack, Netfilter, CNIs, overlay networks, and everything else in the Kubernetes networking toolbox required for effective communication.



# pod creation


when we first create a pod the CRI create the network namespace an then CNI assigne an ip adress to the container and attache it to network 
 container runtimes are responsible for loading container images from a repository, monitoring local system resources, isolating system resources for use of a container, and managing container lifecycle. 
 

Instead of running ip netns and creating the network namespace manually, the container runtime does this automatically.

When you create a pod, and that pod gets assigned to a node, the CNI will:

Assign an IP address.
Attach the container(s) to the network.

if you inspect the network namspases created in your host you will see 

ip netns list 

we have a benche of network namespaces with name pause , what is it ?

lets now list all proccesses in the node 

docker ps | grep pause 

This pause container is responsible for creating and holding the network namespace. 
The network namespace creation is done by the underlaying container runtime. Usually containerd or CRI-O.

https://www.ianlewis.org/en/almighty-pause-container

# assigne ip to pod 
When a pod gets assigned to a specific node, the kubelet itself doesn't initialize the networking.

Instead, it offloads this task to the CNI.

However, it does specify the configuration and sends it over in a JSON format to the CNI plugin.

diagram kubelet cni 


The CNI create veth pairs automaticly to gareentee that the pod can access the host through the bridge 
Without a CNI in place, you would need to manually:

Create interfaces.
Create veth pairs.
Set up the namespace networking.
Set up static routes.
Configure an ethernet bridge.
Assign IP addresses.
Create NAT rules.

what is an CNI https://github.com/containernetworking/cni/blob/main/SPEC.md

Instead, it offloads this task to the CNI.

You can navigate to /etc/cni/net.d on the node and check the current CNI configuration


### compare cni 
There are mainly two groups of CNIs.

In the first group, you can find CNIs that use a basic network setup (also called a flat network) and assign IP addresses to pods from the cluster's IP pool.

This could become a burden as you might quickly exhaust all available IP addresses.

Instead, another approach is to use overlay networking.

In simple terms, an overlay network is a secondary network on top of the main (underlay) network.

The overlay network works by encapsulating any packet originating from the underlay network that is destined to a pod on another node.

A popular technology for overlay networks is VXLAN, which enables tunnelling L2 domains over an L3 network.

So which one is better?

Calico uses layer 3 networking paired with the BGP routing protocol to connect pods.

Cilium configures an overlay network with eBPF on layers 3 to 7.

Along with Calico, Cilium supports setting up network policies to restrict traffic.







Inside the pod network namespace, an interface is created, and an IP address is assigned.

list interfaces in namespace 

ip addr to get the ip address of the pod 

find the host end of the interface 

You can also verify that the Nginx container listens for HTTP traffic from within that namespace:

bash
ip netns exec cni-0f226515-e28b-df13-9f16-dd79456825ac netstat -lnp
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name
tcp        0      0 0.0.0.0:80              0.0.0.0:*               LISTEN      692698/nginx: master
tcp6       0      0 :::80                   :::*                    LISTEN      692698/nginx: master


# pod to pod communication 

## in the same node 

show namespaces of both pods 
show interfaces in host and ns 
show connection to bridge 

diagram 

communication between pod is in L2 level wecause they are connected to the bridge (use arp table)

Since the destination isn't one of the containers in the namespace, Pod-A sends out a packet to its default interface eth0. This interface is tied to the one end of the veth pair and serves as a tunnel. With that, packets are forwarded to the root namespace on the node.

## in separate nodes 

diagram 

The first couple of steps stay the same, up to the point when the packet arrives in the root namespace and needs to be sent over to Pod-B.

This time, the ARP resolution doesn't happen because the source and the destination IP are on different l2 segments .

paquet will be forwarded to default gateway in the 1st node 

now the node must find the route to send the packet after find in in routing table the ARP will check its lookup table for the MAC address of the default gateway.
If there is an entry, it will immediately forward the packet.

Otherwise, it will first do a broadcast to determine the MAC address of the gateway of the destination node 

dummary:
When the request starts at Pod-A, and it wants to reach Pod-B, there is an additional change happening halfway through the transfer.

The originating request exits through the eth0 interface in the Pod-A namespace.

From there, it goes through the veth pair and reaches the root namespace ethernet bridge.

Once at the bridge, the packet gets immediately forwarded through the default gateway.
arp resolution to find the mac address of the desfault gateway of node B

## kubernetes services 
Intercepting and rewriting traffic with Netfilter and Iptables
The service in Kubernetes is built upon two Linux kernel components:

Netfilter and
iptables.

When a packet arrives, and depending on which stage it is, it will 'trigger' a Netfilter hook, which applies a specific iptables filtering.

check iptables rules in the nodes iptables-save 

In Pod-to-Service, the first half of the communication stays the same.

diagram

When the request starts at Pod-A, and it wants to reach Pod-B, which in this case will be 'behind' a service, there is an additional change happening halfway through the transfer.

The originating request exits through the eth0 interface in the Pod-A namespace.

From there, it goes through the veth pair and reaches the root namespace ethernet bridge.

Once at the bridge, the packet gets immediately forwarded through the default gateway.
As in the Pod-to-Pod section, the host makes a bitwise comparison, and because the vIP of the service isn't part of the node's CIDR, the packet will be instantly forwarded through the default gateway.

The same ARP resolution will happen to find out the MAC address of the default gateway if it isn't already present in the lookup table.

Now the magic happens.

Just before that packet goes through the routing process of the node A, the NF_IP_PRE_ROUTING Netfilter hook gets triggered, and an iptables rule is applied. The rule does a DNAT change and rewrites Pod's A packet destination IP.

figure 
The previous service vIP destination gets rewritten to the Pod's B IP address.

From there, the routing is just as same as directly communicating Pod-to-Pod.

Conntrack ???

### sending back the response 