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
    @IBOutlet weak var garageTOGGLE: UIButton!
    @IBOutlet weak var statusLabel: UILabel!

    
    let locationManager = CLLocationManager()
    
    let homeLocation: CLLocation = CLLocation(latitude: 42.572215, longitude: -83.488498)
    let homeDistanceThresh: Double = 200.0
    
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

    @IBAction func wasGarageTOGGLEButtonPressed(_ sender: UIButton) {
        self.locationManager.startUpdatingLocation()
        
        sendPublishStringCommandWith(buttonState: "TOGGLE", gpioNum: 17, homeDistanceThresh: homeDistanceThresh, indicatorLabel: statusLabel)
    }
    
    
    @IBAction func sliderValueChanged(_ sender: UISlider) {
        print("\(sender.value)")

        let iotDataManager = AWSIoTDataManager.default()
        let tabBarViewController = tabBarController as! IoTSampleTabBarController

        iotDataManager?.publishString("\(sender.value)", onTopic:tabBarViewController.topic, qoS:.messageDeliveryAttemptedAtMostOnce)
    }
    
    func sendPublishStringCommandWith(buttonState: String, gpioNum: Int, homeDistanceThresh: Double, indicatorLabel: UILabel) {
        
        guard let distanceToHome = locationManager.location?.distance(from: homeLocation) else { return }
        
        if distanceToHome < homeDistanceThresh {
            let iotDataManager = AWSIoTDataManager.default()
            iotDataManager?.publishString("{\"state\":{\"reported\":{\"ON_OFF\":\"\(buttonState)\",\"GPIO\":\(gpioNum)}}}", onTopic:"Garage", qoS:.messageDeliveryAttemptedAtMostOnce)
            indicatorLabel.text = "Within Distance Threshold, passed \(buttonState) to \(gpioNum)"
        }
        else {
            indicatorLabel.text = "Outside of Distance Threshold. Garage command not sent."
        }
    }
    
}
