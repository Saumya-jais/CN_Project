package org.traffic.app;

import org.osgi.service.component.annotations.Activate;
import org.osgi.service.component.annotations.Component;
import org.osgi.service.component.annotations.Deactivate;
import org.osgi.service.component.annotations.Reference;
import org.osgi.service.component.annotations.ReferenceCardinality;
import org.onosproject.core.ApplicationId;
import org.onosproject.core.CoreService;
import org.onosproject.net.device.DeviceService;
import org.onosproject.net.flow.FlowRuleService;
import org.onosproject.net.packet.PacketService;
import org.onosproject.net.topology.TopologyService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Main component for the Traffic Management application.
 */
@Component(immediate = true)
public class AppComponent {

    private final Logger log = LoggerFactory.getLogger(getClass());

    @Reference(cardinality = ReferenceCardinality.MANDATORY)
    protected CoreService coreService;

    @Reference(cardinality = ReferenceCardinality.MANDATORY)
    protected DeviceService deviceService;

    @Reference(cardinality = ReferenceCardinality.MANDATORY)
    protected FlowRuleService flowRuleService;

    @Reference(cardinality = ReferenceCardinality.MANDATORY)
    protected PacketService packetService;

    @Reference(cardinality = ReferenceCardinality.MANDATORY)
    protected TopologyService topologyService;

    private ApplicationId appId;
    private TrafficMonitor trafficMonitor;

    @Activate
    protected void activate() {
        appId = coreService.registerApplication("org.traffic.app");
        
        // Initialize and start the traffic monitor
        trafficMonitor = new TrafficMonitor(deviceService, flowRuleService, appId);
        trafficMonitor.start();
        
        log.info("Started Traffic Management Application");
    }

    @Deactivate
    protected void deactivate() {
        // Stop traffic monitor
        if (trafficMonitor != null) {
            trafficMonitor.stop();
        }
        
        log.info("Stopped Traffic Management Application");
    }
}
