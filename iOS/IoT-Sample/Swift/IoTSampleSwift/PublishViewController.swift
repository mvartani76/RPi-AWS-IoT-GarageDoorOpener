/*
* Copyright 2010-2016 Amazon.com, Inc. or its affiliates. All Rights Reserved.
*
* Licensed under the Apache License, Version 2.0 (the "License").
* You may not use this file except in compliance with the License.
* A copy of the License is located at
*
*  http://aws.amazon.com/apache2.0
*
* or in the "license" file accompanying this file. This file is distributed
* on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
* express or implied. See the License for the specific language governing
* permissions and limitations under the License.
*/

import UIKit
import AWSIoT
import CoreLocation

class PublishViewController: UIViewController, CLLocationManagerDelegate {

    @IBOutlet weak var publishSlider: UISlider!
    @IBOutlet weak var publishButton: UIButton!
    @IBOutlet weak var GarageON: UIButton!
    @IBOutlet weak var GarageOFF: UIButton!
    
    let locationManager = CLLocationManager()
    
    let homeLocation: CLLocation = CLLocation(latitude: 42.572215, longitude: -83.488498)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        self.locationManager.requestWhenInUseAuthorization()
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        CLGeocoder().reverseGeocodeLocation(manager.location!, completionHandler: {(placemarks, error) -> Void in
            
            if (error != nil) {
                print("ERROR:" + (error?.localizedDescription)!)
            }
            else if (placemarks?.count)! > 0 {
                let pm = (placemarks?[0])! as CLPlacemark
                self.displayLocationInfo(placemark: pm)
            }
            else {
                print("Error with Data")
            }
            self.locationManager.stopUpdatingLocation()
        })
    }
    
    func displayLocationInfo(placemark: CLPlacemark) {
        
        print(placemark.locality)
        print(placemark.postalCode)
        print(placemark.administrativeArea)
        print(placemark.country)
        print(placemark.location)
    }
    
    func locationManager(manager: CLLocationManager!, didFailWithError error: Error) {
        print("Error:" + error.localizedDescription)
    }
    
    @IBAction func ButtonPressed(_ sender: UIButton) {
        self.locationManager.startUpdatingLocation()
        
        guard let distanceToHome = locationManager.location?.distance(from: homeLocation) else { return }
        
        if distanceToHome < 200 {
        
            let iotDataManager = AWSIoTDataManager.default()
            iotDataManager?.publishString("{\"state\":{\"reported\":{\"ON_OFF\":\"TOGGLE\",\"GPIO\":17}}}", onTopic:"Garage", qoS:.messageDeliveryAttemptedAtMostOnce)
        }
    }
    
    @IBAction func ONGarageButtonPressed() {
        self.locationManager.startUpdatingLocation()
        
        guard let distanceToHome = locationManager.location?.distance(from: homeLocation) else { return }
        
        if distanceToHome < 200 {
        
            let iotDataManager = AWSIoTDataManager.default()
            iotDataManager?.publishString("{\"state\":{\"reported\":{\"ON_OFF\":\"ON\",\"GPIO\":17}}}", onTopic:"Garage", qoS:.messageDeliveryAttemptedAtMostOnce)
        }
    }

    @IBAction func OFFGarageButtonPressed() {
        self.locationManager.startUpdatingLocation()
        
        guard let distanceToHome = locationManager.location?.distance(from: homeLocation) else { return }
        
        if distanceToHome < 200 {
            let iotDataManager = AWSIoTDataManager.default()
            iotDataManager?.publishString("{\"state\":{\"reported\":{\"ON_OFF\":\"OFF\",\"GPIO\":17}}}", onTopic:"Garage", qoS:.messageDeliveryAttemptedAtMostOnce)
        }
    }
    
    @IBAction func sliderValueChanged(_ sender: UISlider) {
        print("\(sender.value)")

        let iotDataManager = AWSIoTDataManager.default()
        let tabBarViewController = tabBarController as! IoTSampleTabBarController

        iotDataManager?.publishString("\(sender.value)", onTopic:tabBarViewController.topic, qoS:.messageDeliveryAttemptedAtMostOnce)
    }
}
