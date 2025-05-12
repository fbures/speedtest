//
//  SpeedTest.swift
//  SpeedTest
//
//  Created by František Bureš on 09.05.2025.
//

import Foundation
import CoreLocation
import UIKit

// Declaring constant
let downloadSize = 50000000 // bytes
let testDuration = 15 // seconds
let maxServers = 5 // maximim servers to be PING tested

class SpeedTest: NSObject {
    /// External Ping manager which uses Apple sample ping project
    let pingManager = SimplePingManager()
    
    /// External view items to show progress (also can be done using callback)
    var pingTime: UILabel? = nil
    var downloadSpeed: UILabel? = nil
    var serverName: UILabel? = nil
    var startButton: UIButton? = nil

    /// used to start fininshing current task
    var stopping: Bool = false

    /// Callback to finish all tasks and prepare for new measurement
    var callback: (() -> Void)? = nil
    
    /// Set external resources and callback
    /// - Parameters:
    ///   - pingTime: actual best ping
    ///   - downloadSpeed: actual/average download speed
    ///   - serverName: Server provider
    ///   - callback: callback to finish all tasks
    func setViewItems(pingTime: UILabel, downloadSpeed: UILabel, serverName: UILabel, callback:@escaping (() -> Void)) {
        self.pingTime = pingTime
        self.downloadSpeed = downloadSpeed
        self.serverName = serverName
        self.callback = callback
    }
    
    /// Get servers, select 5 closest ones, send pings and select one having best ping time
    /// - Parameters:
    ///   - servers: response from servers request
    ///   - ip: client IP address details
    ///   - clientLatitude: phone/network provider location
    ///   - clientLongitude: phone/network provider location
    /// - Returns: selected server
    func getClosestServer(servers: [[AnyHashable : Any]], ip: [AnyHashable: Any], clientLatitude: Double, clientLongitude: Double) -> String? {
        var distanceDictionary: [Double: String] = [:]
        let clientCoord = CLLocation(latitude: clientLatitude, longitude: clientLongitude)

        // calculate distances
        for server in servers {
            let serverLogitude: Double? = server["longitude"] as? Double
            let serverLatitude: Double? = server["latitude"] as? Double
            let serverCoord = CLLocation(latitude: serverLatitude!, longitude: serverLogitude!)
            let distance: Double = clientCoord.distance(from: serverCoord) // distance in meters

            if (distanceDictionary[distance] == nil)  {
                distanceDictionary[distance] = server["url"] as? String
            }
            else    {
                // small workaround for duplicate keys(strange, how is it possible?) (+ 1 cm)
                // following ping will differentiate the chosen one
                distanceDictionary[distance + 0.01] = server["url"] as? String
            }
        }

        let sortedDistanceDictionary = distanceDictionary.sorted() { $0.key < $1.key }

        var pingDictionary: [String: TimeInterval] = [:]
        let pingRead = DispatchSemaphore(value : 0)
        var index: UInt16 = 0

        // Run PINGs and create new dictionary including results
        for server in sortedDistanceDictionary {
            if (self.stopping)  {
                return nil
            }

            let dataArray = server.value.components(separatedBy: ":") // https://url:port
            let server : String = String(dataArray[1].dropFirst(2))
            let serverWithPort : String = String(dataArray[1].dropFirst(2)) + ":" + String(dataArray[2])
            var IP : String = ""
            DispatchQueue.main.async { // it needs to run on main thread
                self.pingManager.start(hostName: server, forceIPv4: false, forceIPv6: false) { result in
                    //print(result)
                    switch result {
                    case .sent(_,_):
                        if (validateIpAddress(ipToValidate: IP)) {
                            pingDictionary[serverWithPort] = NSDate().timeIntervalSince1970
                        }
                    case .received(_,_):
                        if (validateIpAddress(ipToValidate: IP)) {
                            pingDictionary[serverWithPort] = NSDate().timeIntervalSince1970 - pingDictionary[serverWithPort]!
                        }
                        self.pingManager.stop()
                        IP = ""
                        pingRead.signal()
                    case .start(let value):
                        IP = value
                    case .sendFailed(_, _, _):
                        IP = "SendFailed"
                    case .unexpectedPacket(_):
                        IP = "Unexpected packet"
                    case .failed(_):
                        IP = "Failed"
                    }
                }
            }

            pingRead.wait()
            if (index == maxServers) { // servers maximum
                break
            }
            index += 1;
        }

        var minPing: TimeInterval = Double.greatestFiniteMagnitude
        var selectedServer: String = ""
        // Find minimal PING
        for (key, value) in pingDictionary {
            if (minPing > value)    {
                minPing = value
                selectedServer = key
            }
        }

        minPing = minPing * 1000
        minPing = round(minPing * 1000) / 1000

        var providerName: String = ""
        for server in servers {
            if (server["url"] as! String == String("https://") + selectedServer) {
                providerName = server["provider"] as! String
                break
            }
        }

        if (self.stopping)  {
            return nil
        }

        DispatchQueue.main.async { // it needs to run on main thread
            self.pingTime?.text = "Ping: " + String(format: "%.3f", minPing) + "ms"
            self.serverName?.text = "Server: " + providerName
        }

        return selectedServer
    }
    
    /// Generate random string like in javascript
    /// - Parameter length: length
    /// - Returns: random string
    static func randomAlphanumericString(_ length: Int) -> String {
       let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890"
       let len = UInt32(letters.count)
       var random = SystemRandomNumberGenerator()
       var randomString = ""
       for _ in 0..<length {
          let randomIndex = Int(random.next(upperBound: len))
          let randomCharacter = letters[letters.index(letters.startIndex, offsetBy: randomIndex)]
          randomString.append(randomCharacter)
       }
       return randomString
    }
    
    /// Start downloading sample data, measure times and write average speed
    /// - Parameters:
    ///   - server: selected server
    ///   - token: token
    /// - Returns:
    func downloadTest(server: String, token: String) -> Void {
        // random string dunped from Javascript, not sure what is this for
        let jN: String = SpeedTest.randomAlphanumericString(7)
        var errorString: String = ""
        let startTest: TimeInterval = Date().timeIntervalSince1970
        var averageSpeedSum: Double = 0
        var averageSpeedCount: UInt64 = 0

        while (Date().timeIntervalSince1970 - startTest < TimeInterval(testDuration)) {

            if (self.stopping)  {
                return
            }

            let downloadStart: TimeInterval = Date().timeIntervalSince1970
            let _ = send(url: "https://" + server + "/download?size=" + String(downloadSize) + "?nc=" + jN + "?token=" + token, method: "GET", errorString: &errorString, token: token, ignoreOutput: true)
            if (errorString != "")  {
                DispatchQueue.main.async { // it needs to run on main thread
                    self.downloadSpeed?.text = "DownloadSpeed: ERROR: " + errorString
                }
                break
            }

            let speed : Double = round(Double(downloadSize) / (Date().timeIntervalSince1970 - downloadStart) / 1000) / 1000
            averageSpeedSum += speed
            averageSpeedCount += 1

            DispatchQueue.main.async { // it needs to run on main thread
                self.downloadSpeed?.text = "Download Speed: " + String(format: "%.3f", speed) + "MBps"
            }
        }

        // last update to have the average speed
        let averageSpeed: Double = averageSpeedSum / Double(averageSpeedCount)
        DispatchQueue.main.async { // it needs to run on main thread
            self.downloadSpeed?.text = "Download Speed: " + String(format: "%.3f", averageSpeed) + "MBps"
        }

    }
    
    /// Init test, get token, get IP address info, get servers and run measurement
    /// - Parameters:
    ///   - lat: GPS location (if available)
    ///   - lon: GPS location (if available)
    /// - Returns:
    func startTest(lat: Double, lon: Double) -> Void {
        self.stopping = false

        var errorString: String = ""
        let tokenReply = send(url: "https://sp-dir.uwn.com/api/v1/tokens", method: "POST", errorString: &errorString)
        if (errorString != "")  {
            DispatchQueue.main.async { // it needs to run on main thread
                self.downloadSpeed?.text = "ERROR: Cannot download token: " + errorString
            }
            self.callback?()
            return
        }

        let token: String? = tokenReply["token"] as? String
        if (token == nil)   {
            DispatchQueue.main.async { // it needs to run on main thread
                self.downloadSpeed?.text = "ERROR: Cannot read token" + errorString
            }
            self.callback?()
            return
        }

        let ipReply = send(url: "https://sp-dir.uwn.com/api/v1/ip", method: "GET", errorString: &errorString)
        if (errorString != "")  {
            DispatchQueue.main.async { // it needs to run on main thread
                self.downloadSpeed?.text = "ERROR: Cannot identify IP address: " + errorString
            }
            self.callback?()
            return
        }


        let serversReply = sendComplex(url: "https://sp-dir.uwn.com/api/v2/servers?secured=only", method: "GET", errorString: &errorString)
        if (errorString != "")  {
            DispatchQueue.main.async { // it needs to run on main thread
                self.downloadSpeed?.text = "ERROR: Cannot download server list: " + errorString
            }
            self.callback?()
            return
        }

        var clientLatitude: Double = lat
        var clientLogitude: Double = lon

        // Get location from IP provider instead
        if (lat == 0 || lon == 0)  {
            clientLogitude = (ipReply["lon"] as? Double)!
            clientLatitude = (ipReply["lat"] as? Double)!
        }

        let closestServerUrl = getClosestServer(servers: serversReply, ip: ipReply, clientLatitude: clientLatitude, clientLongitude: clientLogitude)
        if (closestServerUrl != nil && token != nil)   {
            downloadTest(server: closestServerUrl!, token: token!)
        }

        self.callback?()
    }
    
    /// Inititate stopping of the test
    /// - Returns:
    func stopTest() -> Void {
        self.stopping = true
    }

}
