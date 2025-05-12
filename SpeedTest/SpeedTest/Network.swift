//
//  Network.swift
//  SpeedTest
//
//  Created by František Bureš on 09.05.2025.
//

import Foundation

/// Send request
/// - Parameters:
///   - url: http or https URL
///   - method: GET/POST
///   - errorString: output error string
///   - token: token, if available
///   - ignoreOutput: ignore output data
/// - Returns: simple JSON dictionary
func send(url: String, method: String, errorString: inout String, token: String? = nil, ignoreOutput: Bool = false) -> [AnyHashable : Any]{
    errorString = ""
    let s = DispatchSemaphore(value : 0)
    let urlInstance = URL(string: url)!
    var result: [AnyHashable : Any] = [:]
    var request = URLRequest(url: urlInstance)
    request.httpMethod = method
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    if (token != nil)  { // got stuck here a lot, needed for download
        request.setValue(token!, forHTTPHeaderField: "x-test-token")
    }
    var localErrorString: String = ""

    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        guard let data = data, error == nil else {
            localErrorString = error?.localizedDescription ?? "No data"
            s.signal()
            return
        }

        if (ignoreOutput)   {
            s.signal()
            return
        }

        let responseJSON = try? JSONSerialization.jsonObject(with: data, options: .allowFragments)

        if let responseJSON = responseJSON as? [AnyHashable: Any] {
            result = responseJSON
        }
        else {
            localErrorString = "Response JSON is nil, or is not a [AnyHashable: Any]"
        }
        s.signal()
    }
    task.resume()
    s.wait()
    errorString = localErrorString
    return result;
}

/// <#Description#>
/// - Parameters:
///   - url: http or https URL
///   - method: GET/POST
///   - errorString: output error string
/// - Returns: complex JSON dictionary
func sendComplex(url: String, method: String, errorString: inout String) -> [[AnyHashable : Any]]{
    errorString = ""
    let s = DispatchSemaphore(value : 0)
    let urlInstance = URL(string: url)!
    var result: [[AnyHashable : Any]] = [[:]]
    var request = URLRequest(url: urlInstance)
    var localErrorString: String = ""
    request.httpMethod = method
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        guard let data = data, error == nil else {
            localErrorString = error?.localizedDescription ?? "No data"
            s.signal()
            return
        }

        let responseJSON = try? JSONSerialization.jsonObject(with: data, options: .allowFragments)

        if let responseJSON = responseJSON as? [[AnyHashable: Any]] {
            result = responseJSON
        }
        else {
            localErrorString = "Response JSON is nil, or is not a [[AnyHashable: Any]]"
        }
        s.signal()
    }
    task.resume()
    s.wait()
    errorString = localErrorString
    return result;
}

/// Validate IP address
/// - Parameter ipToValidate: input IP address
/// - Returns: true if is valid
func validateIpAddress(ipToValidate: String) -> Bool {

    var sin = sockaddr_in()
    var sin6 = sockaddr_in6()

    if ipToValidate.withCString({ cstring in inet_pton(AF_INET6, cstring, &sin6.sin6_addr) }) == 1 {
        // IPv6 peer.
        return true
    }
    else if ipToValidate.withCString({ cstring in inet_pton(AF_INET, cstring, &sin.sin_addr) }) == 1 {
        // IPv4 peer.
        return true
    }

    return false;
}
