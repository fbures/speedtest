//
//  ViewController.swift
//  SpeedTest
//
//  Created by František Bureš on 09.05.2025.
//

import UIKit
import CoreLocation

class ViewController: UIViewController, CLLocationManagerDelegate {
    @IBOutlet weak var downloadSpeed: UILabel!
    @IBOutlet weak var pingTime: UILabel!
    @IBOutlet weak var serverName: UILabel!
    @IBOutlet weak var start: UIButton!

    var locationManager = CLLocationManager()
    var clientLogitude: Double = 0
    var clientLatitude: Double = 0
    /// signaling read coordinates
    let locationRead = DispatchSemaphore(value : 0)
    var locationServicesEnabled: Bool = false
    private let queue = DispatchQueue.global(qos: .background)
    let speedTest = SpeedTest()
    var starting: Bool = false

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationManager.stopUpdatingLocation()
        //print(error)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation])  {
        let locationArray = locations as NSArray
        let locationObj = locationArray.lastObject as! CLLocation
        let coord = locationObj.coordinate

        self.clientLogitude = coord.longitude
        self.clientLatitude = coord.latitude
        locationManager.stopUpdatingLocation()
        locationRead.signal();
    }

    private func checkLocationAuthorization()   {
        switch locationManager.authorizationStatus{
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .restricted:
            return
        case .denied:
            return
        case .authorizedWhenInUse, .authorizedAlways:
            /// app is authorized
            /// locationManager.distanceFilter = kCLDistanceFilterNone
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.startUpdatingLocation()
            self.locationServicesEnabled = true
            locationManager.startUpdatingLocation()
        default:
            break
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        checkLocationAuthorization()
    }

    /// Start/Stop button pressed
    /// - Parameter sender: sender
    @IBAction func press(_ sender: Any) {
        self.serverName?.text = "Server: "
        self.pingTime?.text = "Ping: "
        self.downloadSpeed?.text = "Download Speed: "

        if (starting)   {
            self.speedTest.stopTest()
            self.start?.setTitle("Start", for: .normal)
            self.starting = false
        }
        else {
            self.starting = true
            self.start?.setTitle("Stop", for: .normal)
            if (self.locationServicesEnabled && self.clientLogitude == 0 && self.clientLatitude == 0)  {
                locationRead.wait()
            }

            // must run it in any other than main thread
            queue.async { [weak self] in
                guard let s = self else { return }
                s.speedTest.startTest(lat: s.clientLatitude, lon: s.clientLogitude)
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        speedTest.setViewItems(pingTime: self.pingTime, downloadSpeed: self.downloadSpeed, serverName: self.serverName) {
            self.starting = false
            DispatchQueue.main.async { // it needs to run on main thread
                self.start?.setTitle("Start", for: .normal)
            }
        }

        locationManager.delegate = self
        if self.locationManager.authorizationStatus == .notDetermined {
            self.locationManager.requestWhenInUseAuthorization()
        }
    }


}

