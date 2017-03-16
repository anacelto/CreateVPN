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
    
    /// Connection to oor
    open var oor: NWUDPSession?
    
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
    
    // Start reading incoming packets
    /* connectionUDP?.setReadHandler({dataArray, error in
        NSLog("CREATEVPN.setReadhandler ERROR \(error)")
        self.newIncomingPackets(packets: dataArray!)
    }, maxDatagrams: 32) */
    
    // Start handling outgoing packets coming from the TUN
    startHandlingPackets()
    
    reach()
    
    NSLog("TUNNEL STARTED")
}
    
    
    func startOOR() {
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Call to C function to create the swift - c socket and start OOR
            createSocket()
        }
        
        // Connect to OOR Socket
        var endpoint: NWEndpoint
        endpoint = NWHostEndpoint(hostname: "127.0.0.1", port: "8888")
        oor = self.createUDPSession(to: endpoint, from: nil)
        
        // Start listeing incoming packets coming from OOR
        oor?.setReadHandler({dataArray, error in
            NSLog("CREATEVPN.OOR.setReadhandler ERROR \(error)")
            self.newOORPackets(packets: dataArray!)
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
        
        /* for packet in packets {
            // Create a pointer to the packet
            //let pPacket = UnsafeMutablePointer<UInt8>.allocate(capacity: 60)
            //packet.copyBytes(to: pPacket, count: 50)
        } */
        
        // Write packets to OOR
        oor?.writeMultipleDatagrams(packets) { error in
            if error != nil {
                NSLog("CREATEVPN.Provider: connectionUDP.write error: \(error)")
            }
        }
        
        // Read more outgoing packets coming from the TUN
        self.packetFlow.readPackets { inPackets, inProtocols in
            self.handlePackets(inPackets, protocols: inProtocols)
        }
    }

    func newOORPackets(packets: [Data]) {
        
        NSLog("PacketFromOOR")
        
        /*var rloc = NWUDPSession()
        
        // Connect to supposed RLOC
        var endpoint: NWEndpoint
        endpoint = NWHostEndpoint(hostname: "10.192.243.26", port: "55057")
        rloc = self.createUDPSession(to: endpoint, from: nil)
        

        
        // Write packets to supposed RLOC
        oor?.writeMultipleDatagrams(packets) { error in
            if error != nil {
                NSLog("CREATEVPN.Provider: connectionUDP.write error: \(error)")
            }
        }*/
    }
    
    // Handle incoming packets from WAN
    func newIncomingPackets(packets: [Data]) {
        
        var protocolArray = [NSNumber]()
        
        for packet in packets {
            protocolArray.append(0x02)
            // Create a pointer to the packet
            //let pPacket = UnsafeMutablePointer<UInt8>.allocate(capacity: 60)
            //packet.copyBytes(to: pPacket, count: 50)
            // Send the packet to OOR
            
         }
        
       // Write packets coming from OOR to TUN
       packetFlow.writePackets(packets, withProtocols: protocolArray)
    }
    
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
