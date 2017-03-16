/*
 Copyright (c) 2014, Ashley Mills
 All rights reserved.
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 */
//
//  Reachability.swift
//  Reachability Swift 3
//
//  updated by lsd on 8/17/16.
//  Copyright © 2016 Leonardo Savio Dabus. All rights reserved.
//  Xcode 8 beta 6 • Swift 3

import SystemConfiguration
import Foundation

var reachability: Reachability?

enum ReachabilityError: Error {
    case failedToCreateWithAddress(sockaddr_in)
    case failedToCreateWithHostname(String)
    case unableToSetCallback
    case unableToSetDispatchQueue
}

extension Notification.Name {
    static let reachabilityChanged = Notification.Name("reachabilityChanged")
}

fileprivate func callout(reachability: SCNetworkReachability, flags: SCNetworkReachabilityFlags, info: UnsafeMutableRawPointer?) {
    guard let info = info else { return }
    DispatchQueue.main.async {
        Unmanaged<Reachability>.fromOpaque(info).takeUnretainedValue().reachabilityChanged()
    }
}

class Reachability {
    
    enum NetworkStatus: String {
        case notReachable, reachableViaWiFi, reachableViaWWAN
        var description: String {
            switch self {
            case .reachableViaWWAN:
                return "Reachable via Cellular"
            case .reachableViaWiFi:
                return "Reachable via WiFi"
            case .notReachable:
                return "Not Reachable"
            }
        }
    }
    
    var reachableOnWWAN: Bool
    
    var networkStatus: NetworkStatus {
        if !connectedToNetwork { return .notReachable     }
        if reachableViaWiFi    { return .reachableViaWiFi }
        return runningOnDevice ? .reachableViaWWAN : .notReachable
    }
    
    var previousFlags: SCNetworkReachabilityFlags?
    
    var runningOnDevice: Bool = {
        #if (arch(i386) || arch(x86_64)) && os(iOS)
            return false
        #else
            return true
        #endif
    }()
    
    var notifierRunning = false
    var networkReachability: SCNetworkReachability?
    let reachabilitySerialQueue = DispatchQueue(label: "reachabilitySerialQueue")
    
    required init(networkReachability: SCNetworkReachability) {
        reachableOnWWAN = true
        self.networkReachability = networkReachability
    }
    
    convenience init?(hostname: String) throws {
        guard let networkReachability = SCNetworkReachabilityCreateWithName(nil, hostname) else {
            throw ReachabilityError.failedToCreateWithHostname(hostname)
        }
        self.init(networkReachability: networkReachability)
    }
    
    
    convenience init?() throws {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        zeroAddress.sin_family = sa_family_t(AF_INET)
        guard let networkReachability = withUnsafePointer(to: &zeroAddress, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            SCNetworkReachabilityCreateWithAddress(nil, $0)
        }}) else {
            throw ReachabilityError.failedToCreateWithAddress(zeroAddress)
        }
        self.init(networkReachability: networkReachability)
    }
    
    deinit {
        stopNotifier()
        networkReachability = nil
    }
}

extension Reachability {
    func startNotifier() throws {
        guard let networkReachability = networkReachability, !notifierRunning else { return }
        var context = SCNetworkReachabilityContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
        context.info = UnsafeMutableRawPointer(Unmanaged<Reachability>.passUnretained(self).toOpaque())
        if !SCNetworkReachabilitySetCallback(networkReachability, callout, &context) {
            stopNotifier()
            throw ReachabilityError.unableToSetCallback
        }
        if !SCNetworkReachabilitySetDispatchQueue(networkReachability, reachabilitySerialQueue) {
            stopNotifier()
            throw ReachabilityError.unableToSetDispatchQueue
        }
        reachabilitySerialQueue.async {
            self.reachabilityChanged()
        }
        notifierRunning = true
    }
    
    func stopNotifier() {
        defer { notifierRunning = false }
        guard let networkReachability = networkReachability else { return }
        SCNetworkReachabilitySetCallback(networkReachability, nil, nil)
        SCNetworkReachabilitySetDispatchQueue(networkReachability, nil)
    }
    
    var connectedToNetwork: Bool {
        if !reachable { return false }
        if connectionRequiredAndTransient { return false }
        if runningOnDevice { if isWWAN && !reachableOnWWAN { return false } }
        return true
    }
    
    var reachableViaWWAN: Bool {
        return runningOnDevice && reachable && isWWAN
    }
    
    var reachableViaWiFi: Bool {
        guard reachable else { return false }
        guard runningOnDevice  else { return true  }
        return !isWWAN
    }
    
    var description: String {
        var result  = runningOnDevice ? (isWWAN ? "W" : "-") : "X"
            result += reachable ? "R " : "- "
            result += connectionRequired ? "c" : "-"
            result += transientConnection ? "t" : "-"
            result += interventionRequired ? "i" : "-"
            result += connectionOnTraffic ? "C" : "-"
            result += connectionOnDemand ? "D" : "-"
            result += isLocalAddress ? "l" : "-"
            result += isDirect ? "d" : "-"
        return result
    }
    
    func reachabilityChanged() {
        guard previousFlags != flags else { return }
        previousFlags = flags
        NotificationCenter.default.post(name: .reachabilityChanged, object: self)
    }
    var isWWAN: Bool {
        return flags.contains(.isWWAN)
    }
    var reachable: Bool {
        return flags.contains(.reachable)
    }
    var connectionRequired: Bool {
        return flags.contains(.connectionRequired)
    }
    var interventionRequired: Bool {
        return flags.contains(.interventionRequired)
    }
    var connectionOnTraffic: Bool {
        return flags.contains(.connectionOnTraffic)
    }
    var connectionOnDemand: Bool {
        return flags.contains(.connectionOnDemand)
    }
    var connectionOnTrafficOrDemand: Bool {
        return !flags.intersection([.connectionOnTraffic, .connectionOnDemand]).isEmpty
    }
    var transientConnection: Bool {
        return flags.contains(.transientConnection)
    }
    var isLocalAddress: Bool {
        return flags.contains(.isLocalAddress)
    }
    var isDirect: Bool {
        return flags.contains(.isDirect)
    }
    var connectionRequiredAndTransient: Bool {
        return flags.intersection([.connectionRequired, .transientConnection]) == [.connectionRequired, .transientConnection]
    }
    var flags: SCNetworkReachabilityFlags {
        guard let networkReachability = networkReachability else { return SCNetworkReachabilityFlags() }
        var reachabilityFlags = SCNetworkReachabilityFlags()
        let gotFlags = withUnsafeMutablePointer(to: &reachabilityFlags) {
            SCNetworkReachabilityGetFlags(networkReachability, UnsafeMutablePointer($0))
        }
        return gotFlags ? reachabilityFlags : SCNetworkReachabilityFlags()
    }
}
