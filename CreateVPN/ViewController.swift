//
//  ViewController.swift
//  CreateVPN
//
//  Created by Oriol Marí Marqués on 17/11/2016.
//  Copyright © 2016 Oriol Marí Marqués. All rights reserved.
//

import UIKit
import NetworkExtension

class ViewController: UIViewController {
    
    private var manager = NETunnelProviderManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func loadFromPreferences(_ sender: AnyObject) {
        manager.loadFromPreferences { error in
            print("loadFromPreferencesError \(error)")
        }
    }
    
    @IBAction func saveToPreferences(_ sender: AnyObject) {
        
        manager.protocolConfiguration = NETunnelProviderProtocol()
        manager.localizedDescription = "VPN ORIOL"
        manager.protocolConfiguration?.serverAddress = "vpn.oriol"
        
        manager.saveToPreferences { error in
            print("saveToPreferencesError \(error)")
        }
    }
    
    @IBAction func removeFromPreferences(_ sender: AnyObject) {
        manager.removeFromPreferences { error in
            print("removeFromPreferencesError \(error)")
        }
    }
    
    private var session: NETunnelProviderSession? {
        return manager.connection as? NETunnelProviderSession
    }
    
    @IBAction func startVPNTunnel(_ sender: AnyObject) {
        do {
            try session?.startTunnel(options: nil)
        }
        catch {
            print("startVPNTunnelError \(error)")
        }
    }
    

}

