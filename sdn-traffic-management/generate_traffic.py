#!/usr/bin/python3

import sys
import time
import subprocess
from threading import Thread

def run_iperf_server(host_name):
    """Run iperf server on specified host"""
    cmd = f"mn -c && mn --host={host_name} iperf -s"
    subprocess.Popen(cmd, shell=True)
    print(f"Started iperf server on {host_name}")

def run_iperf_client(source_host, target_host, duration=20, bandwidth='5M'):
    """Run iperf client from source to target"""
    cmd = f"mn -c && mn --host={source_host} iperf -c {target_host} -t {duration} -b {bandwidth}"
    subprocess.Popen(cmd, shell=True)
    print(f"Started traffic flow from {source_host} to {target_host} at {bandwidth}bps for {duration}s")

def generate_traffic_pattern():
    """Generate a specific traffic pattern to test congestion detection"""
    # Start iperf servers on h5 and h6
    run_iperf_server('h5')
    run_iperf_server('h6')
    
    time.sleep(2)  # Wait for servers to start
    
    # Initial moderate traffic
    print("Starting initial moderate traffic...")
    run_iperf_client('h1', '10.0.0.5', duration=60, bandwidth='2M')
    run_iperf_client('h2', '10.0.0.6', duration=60, bandwidth='2M')
    
    time.sleep(20)  # Let the initial traffic stabilize
    
    # Introduce heavy traffic to create congestion
    print("Introducing heavy traffic to create congestion...")
    run_iperf_client('h3', '10.0.0.5', duration=30, bandwidth='8M')
    run_iperf_client('h4', '10.0.0.6', duration=30, bandwidth='8M')
    
    print("Traffic generation complete. Monitor ONOS for traffic statistics.")

if __name__ == "__main__":
    print("Starting traffic generation...")
    generate_traffic_pattern()
