//
//  PacketTunnelProvider.swift
//  PacketTunnelProvider
//
//  Created by Oriol Marí Marqués on 17/11/2016.
//  Copyright © 2016 Oriol Marí Marqués. All rights reserved.
//

import NetworkExtension

class PacketTunnelProvider: NEPacketTunnelProvider {
 
    /// The completion handler to call when the tunnel is fully established.
    var pendingStartCompletion: ((Error?) -> Void)?
    
    /// Socket to handle outgoing packets with OOR
    open var oorOut: NWUDPSession?
    
    // Socket to handle incoming packets with OOR
    open var oorIn: NWUDPSession?
    
    
    // Start fake tunnel connection
 override func startTunnel(options: [String : NSObject]? = nil, completionHandler: @escaping (Error?) -> Void) {
    
    pendingStartCompletion = completionHandler
    
    // Supposed VPN server IP address
    let newSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "69.69.69.69")
 
    // TUN IP address
    newSettings.iPv4Settings = NEIPv4Settings(addresses: ["70.70.70.70"], subnetMasks: ["255.255.255.0"])
    
    // Networks to be routed through TUN
    newSettings.iPv4Settings?.includedRoutes = [NEIPv4Route.default()]
 
    // newSettings.tunnelOverheadBytes = 1460
    
    // Apply settings and create TUN
    setTunnelNetworkSettings(newSettings) { error in
        NSLog("CREATEVPN.Provider: setTunnelNetworkSettingsError \(error)")
        //completionHandler(NSError(domain: NSOSStatusErrorDomain, code: -4, userInfo: nil))
        // Tell to the system that the fake VPN is "up"
        self.pendingStartCompletion?(nil)
        self.pendingStartCompletion = nil
    }
    
    // Start OOR
    startOOR()
    
    // Start handling outgoing packets coming from the TUN
    startHandlingPackets()
    
    // Start monitoring network changes
    reach()
}
    
    
    func startOOR() {
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Call to C function to create the swift - c socket and start OOR
            createSocket()
        }

        var endpoint: NWEndpoint
        
        // Connect to OOR outgoing Socket
        endpoint = NWHostEndpoint(hostname: "127.0.0.1", port: "8888")
        oorOut = self.createUDPSession(to: endpoint, from: nil)
        
        // Connect to OOR incoming Socket
        endpoint = NWHostEndpoint(hostname: "127.0.0.1", port: "8889")

        
        // Start listeing outgoing packets coming from OOR
        oorOut?.setReadHandler({dataArray, error in
            NSLog("CREATEVPN.OOR.setReadhandler ERROR \(error)")
            self.newOOROutPackets(packets: dataArray!)
        }, maxDatagrams: 1)
        
        // Start listeing incoming packets coming from OOR
        oorIn?.setReadHandler({dataArray, error in
            NSLog("CREATEVPN.OOR.setReadhandler ERROR \(error)")
            self.newOORInPackets(packets: dataArray!)
        }, maxDatagrams: 1)
        
    }
    
    /// Start handling outgoing packets coming from the TUN
    func startHandlingPackets() {
        // Read outgoing packets coming from the TUN
        packetFlow.readPackets { inPackets, inProtocols in
            self.handlePackets(inPackets, protocols: inProtocols)
        }
    }
    
    /// Handle outgoing packets coming from the TUN.
    func handlePackets(_ packets: [Data], protocols: [NSNumber]) {
        
        // Write packets to OOR
        oorOut?.writeMultipleDatagrams(packets) { error in
            if error != nil {
                NSLog("CREATEVPN.Provider: connectionUDP.write error: \(error)")
            }
        }
        
        // Read more outgoing packets coming from the TUN
        self.packetFlow.readPackets { inPackets, inProtocols in
            self.handlePackets(inPackets, protocols: inProtocols)
        }
    }

    // Handle outgoing packets coming from OOR
    func newOOROutPackets(packets: [Data]) {
        
        NSLog("PacketFromOOR")
        
        var rloc = NWUDPSession()
        
        // Connect to supposed RLOC
        var endpoint: NWEndpoint
        endpoint = NWHostEndpoint(hostname: "10.192.243.26", port: "55057")
        rloc = self.createUDPSession(to: endpoint, from: nil)

        // Write outgoing packets to supposed RLOC
        rloc.writeMultipleDatagrams(packets) { error in
            if error != nil {
                NSLog("CREATEVPN.Provider: connectionUDP.write error: \(error)")
            }
        }
    }
    
    // Handle incoming packets from WAN
    func newIncomingPackets(packets: [Data]) {
        
        // Write packets to OOR
        oorIn?.writeMultipleDatagrams(packets) { error in
            if error != nil {
                NSLog("CREATEVPN.Provider: connectionUDP.write error: \(error)")
            }
        }
    }
    
    func newOORInPackets(packets: [Data]) {
        var protocolArray = [NSNumber]()
        for _ in packets { protocolArray.append(0x02) }
        // Write incoming packets coming from OOR to TUN
        packetFlow.writePackets(packets, withProtocols: protocolArray)
    }
    
    // Start monitoring network changes
    func reach() {
        do {
            reachability = try Reachability()
            NotificationCenter.default.addObserver(self, selector: #selector(reachabilityChanged(_:)), name: .reachabilityChanged, object: reachability)
            do {
                try reachability?.startNotifier()
            } catch let error as ReachabilityError {
                print(error.localizedDescription)
            } catch {
                print(error.localizedDescription)
            }
            
        } catch {
            
        }
    }
    
    // handle network change event
    func reachabilityChanged(_ notification: NSNotification) {
        
        guard let reachability = notification.object as? Reachability else { return }
       
        NSLog("NetworkStatus: \(reachability.networkStatus)")
        NSLog("Reachable: \(reachability.reachable)")
        NSLog("Reachable Via WiFi: \(reachability.reachableViaWiFi)")
    }
    
    
    
    
 /*func stopTunnelWithReason(reason: NEProviderStopReason, completionHandler: () -> Void) {
 // Add code here to start the process of stopping the tunnel.
 completionHandler()
 }
 
 func handleAppMessage(messageData: NSData, completionHandler: ((NSData?) -> Void)?) {
 // Add code here to handle the message.
 if let handler = completionHandler {
 handler(messageData)
 }
 }
 
 func sleepWithCompletionHandler(completionHandler: () -> Void) {
 // Add code here to get ready to sleep.
 completionHandler()
 }
 
 override func wake() {
 // Add code here to wake up.
 }*/
 }
