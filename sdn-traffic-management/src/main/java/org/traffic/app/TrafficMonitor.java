package org.traffic.app;

import org.onosproject.core.ApplicationId;
import org.onosproject.net.Device;
import org.onosproject.net.DeviceId;
import org.onosproject.net.device.DeviceService;
import org.onosproject.net.flow.FlowEntry;
import org.onosproject.net.flow.FlowRuleService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.HashMap;
import java.util.Map;
import java.util.Timer;
import java.util.TimerTask;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Module to monitor traffic statistics from network devices.
 */
public class TrafficMonitor {

    private final Logger log = LoggerFactory.getLogger(getClass());
    private final DeviceService deviceService;
    private final FlowRuleService flowRuleService;
    private final ApplicationId appId;
    
    // Store previous statistics to calculate rates
    private final Map<DeviceId, Map<Long, Long>> previousPacketCounts = new ConcurrentHashMap<>();
    private final Map<DeviceId, Map<Long, Long>> previousByteCounts = new ConcurrentHashMap<>();
    
    // Timer for periodical statistics collection
    private Timer timer;
    private static final int POLL_INTERVAL = 5000; // 5 seconds

    /**
     * Creates a new Traffic Monitor.
     *
     * @param deviceService service for accessing network devices
     * @param flowRuleService service for accessing flow rules
     * @param appId application identifier
     */
    public TrafficMonitor(DeviceService deviceService, FlowRuleService flowRuleService, ApplicationId appId) {
        this.deviceService = deviceService;
        this.flowRuleService = flowRuleService;
        this.appId = appId;
    }

    /**
     * Starts the traffic monitoring process.
     */
    public void start() {
        timer = new Timer("traffic-monitor");
        timer.scheduleAtFixedRate(new StatisticsCollector(), 0, POLL_INTERVAL);
        log.info("Started traffic monitoring with interval of {} ms", POLL_INTERVAL);
    }

    /**
     * Stops the traffic monitoring process.
     */
    public void stop() {
        if (timer != null) {
            timer.cancel();
            timer = null;
            log.info("Stopped traffic monitoring");
        }
    }

    /**
     * Timer task for collecting statistics from devices.
     */
    private class StatisticsCollector extends TimerTask {
        @Override
        public void run() {
            try {
                for (Device device : deviceService.getAvailableDevices()) {
                    DeviceId deviceId = device.id();
                    Map<Long, Long> prevPackets = previousPacketCounts.computeIfAbsent(deviceId, k -> new HashMap<>());
                    Map<Long, Long> prevBytes = previousByteCounts.computeIfAbsent(deviceId, k -> new HashMap<>());
                    
                    // Get all flow entries for the device
                    for (FlowEntry flow : flowRuleService.getFlowEntries(deviceId)) {
                        long flowId = flow.id().value();
                        long packets = flow.packets();
                        long bytes = flow.bytes();
                        
                        // Calculate rates
                        Long prevPacketCount = prevPackets.get(flowId);
                        Long prevByteCount = prevBytes.get(flowId);
                        
                        if (prevPacketCount != null && prevByteCount != null) {
                            long packetRate = (packets - prevPacketCount) * 1000 / POLL_INTERVAL; // packets per second
                            long byteRate = (bytes - prevByteCount) * 1000 / POLL_INTERVAL; // bytes per second
                            
                            // Log and analyze traffic patterns
                            log.info("Device {}, Flow {}: {} packets/s, {} bytes/s",
                                     deviceId, flowId, packetRate, byteRate);
                            
                            // Here you will implement congestion detection logic in the future
                            analyzeTraffic(deviceId, flowId, packetRate, byteRate);
                        }
                        
                        // Store current counts for next iteration
                        prevPackets.put(flowId, packets);
                        prevBytes.put(flowId, bytes);
                    }
                }
            } catch (Exception e) {
                log.error("Error collecting traffic statistics", e);
            }
        }
    }

    /**
     * Analyzes traffic patterns for congestion detection.
     * 
     * @param deviceId the device identifier
     * @param flowId the flow identifier
     * @param packetRate the packet rate in packets per second
     * @param byteRate the byte rate in bytes per second
     */
    private void analyzeTraffic(DeviceId deviceId, long flowId, long packetRate, long byteRate) {
        // Simple threshold-based detection
        // This will be enhanced in future iterations
        final long CONGESTION_THRESHOLD_PACKETS = 1000; // 1000 packets/s
        final long CONGESTION_THRESHOLD_BYTES = 1000000; // ~1 MB/s
        
        if (packetRate > CONGESTION_THRESHOLD_PACKETS || byteRate > CONGESTION_THRESHOLD_BYTES) {
            log.warn("Potential congestion detected on device {}, flow {}: {} packets/s, {} bytes/s",
                     deviceId, flowId, packetRate, byteRate);
            
            // Later, this will trigger flow rule modifications
            // handleCongestion(deviceId, flowId);
        }
    }
}
