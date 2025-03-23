#!/usr/bin/python3

from mininet.net import Mininet
from mininet.node import Controller, RemoteController, OVSKernelSwitch
from mininet.cli import CLI
from mininet.log import setLogLevel, info
from mininet.link import TCLink
from functools import partial

def createTestNetwork():
    """Create a network with 4 switches and 6 hosts"""
    
    # Initialize Mininet with Remote Controller (ONOS)
    controller = partial(RemoteController, ip='127.0.0.1', port=6653)
    net = Mininet(controller=controller, switch=OVSKernelSwitch, link=TCLink)
    
    # Add ONOS controller
    c0 = net.addController('c0')
    
    # Create switches
    s1 = net.addSwitch('s1')
    s2 = net.addSwitch('s2')
    s3 = net.addSwitch('s3')
    s4 = net.addSwitch('s4')
    
    # Create hosts
    h1 = net.addHost('h1', mac='00:00:00:00:00:01', ip='10.0.0.1/24')
    h2 = net.addHost('h2', mac='00:00:00:00:00:02', ip='10.0.0.2/24')
    h3 = net.addHost('h3', mac='00:00:00:00:00:03', ip='10.0.0.3/24')
    h4 = net.addHost('h4', mac='00:00:00:00:00:04', ip='10.0.0.4/24')
    h5 = net.addHost('h5', mac='00:00:00:00:00:05', ip='10.0.0.5/24')
    h6 = net.addHost('h6', mac='00:00:00:00:00:06', ip='10.0.0.6/24')
    
    # Create links between switches
    # Main path
    net.addLink(s1, s2, bw=10, delay='5ms')
    net.addLink(s2, s4, bw=10, delay='5ms')
    
    # Alternate path
    net.addLink(s1, s3, bw=5, delay='10ms')
    net.addLink(s3, s4, bw=5, delay='10ms')
    
    # Link switches to hosts
    net.addLink(s1, h1)
    net.addLink(s1, h2)
    net.addLink(s2, h3)
    net.addLink(s3, h4)
    net.addLink(s4, h5)
    net.addLink(s4, h6)
    
    # Start network
    net.build()
    c0.start()
    s1.start([c0])
    s2.start([c0])
    s3.start([c0])
    s4.start([c0])
    
    info('*** Network is running\n')
    
    return net

if __name__ == '__main__':
    setLogLevel('info')
    net = createTestNetwork()
    CLI(net)
    net.stop()
