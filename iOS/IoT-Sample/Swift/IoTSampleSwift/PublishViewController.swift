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

enum SerializationError: Error {
    case missing(String)
    case invalid(String, Any)
}

class PublishViewController: UIViewController, CLLocationManagerDelegate {

    @IBOutlet weak var publishSlider: UISlider!
    @IBOutlet weak var garage1TOGGLE: UIButton!
    @IBOutlet weak var garage2TOGGLE: UIButton!
    @IBOutlet weak var requestSTATUS: UIButton!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var PanelView: UIView!
    
    let locationManager = CLLocationManager()
    
    let homeLocation: CLLocation = CLLocation(latitude: 42.572215, longitude: -83.488498)
    
    
    var timer = Timer()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let iotDataManager = AWSIoTDataManager.default()
        let tabBarViewController = tabBarController as! IoTSampleTabBarController
        
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        self.locationManager.requestWhenInUseAuthorization()

        iotDataManager.subscribe(toTopic: tabBarViewController.topic, qoS: .messageDeliveryAttemptedAtMostOnce, messageCallback: {
            (payload) ->Void in
            let stringValue = String(describing: NSString(data: payload, encoding: String.Encoding.utf8.rawValue)!)

            let data = stringValue.data(using: .utf8)!
            do {
                if let jsonArray = try JSONSerialization.jsonObject(with: data, options :.mutableContainers) as? [String:Any]
                {
                    let jsonState = jsonArray["state"] as! [String:Any]
                    let reportedState = jsonState["reported"] as! [String:Any]
                    let msgState = reportedState["ON_OFF"] as! String

                    if msgState == "UPDATE_STATUS" {
                        let garageState = reportedState["DATA"] as! String
                        self.statusLabel.text = garageState
                    }
                } else {
                    print("bad json")
                }
            } catch let error as NSError {
                print(error)
            }
        } )
        
        // Set the BackgroundColor of PanelView based on distance to home location
        setBackgroundColorBasedOnDistance()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Set the BackgroundColor of PanelView based on distance to home location
        setBackgroundColorBasedOnDistance()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func wasGarageTOGGLEButton1Pressed(_ sender: UIButton) {
        sendGarageToggleCommandWith(buttonState: "TOGGLE", gpioNum: GarageTOGGLEButton1_GPIO, homeDistanceThresh: HomeDistanceThresh, indicatorLabel: statusLabel)
    }
    
    @IBAction func wasGarageTOGGLEButton2Pressed(_ sender: UIButton) {
        sendGarageToggleCommandWith(buttonState: "TOGGLE", gpioNum: GarageTOGGLEButton2_GPIO, homeDistanceThresh: HomeDistanceThresh, indicatorLabel: statusLabel)
    }
    
    @IBAction func wasRequestSTATUSButtonPressed(_ sender: UIButton) {
        sendGarageStatusCommandWith(buttonState: "REQUEST_STATUS", gpioNum: RequestSTATUSButton_GPIO, indicatorLabel: statusLabel)
    }
    
    func sendGarageToggleCommandWith(buttonState: String, gpioNum: Int, homeDistanceThresh: Double, indicatorLabel: UILabel) {
        
        guard let distanceToHome = locationManager.location?.distance(from: homeLocation) else { return }
        
        if distanceToHome < homeDistanceThresh {
            let iotDataManager = AWSIoTDataManager.default()
            iotDataManager.publishString("{\"state\":{\"reported\":{\"ON_OFF\":\"\(buttonState)\",\"GPIO\":\(gpioNum)}}}", onTopic:"Garage", qoS:.messageDeliveryAttemptedAtMostOnce)
            indicatorLabel.text = "Within Distance Threshold, passed \(buttonState) to \(gpioNum)"
        }
        else {
            indicatorLabel.text = "Outside of Distance Threshold. Garage command not sent."
        }
        
        timer = Timer.scheduledTimer(timeInterval: 4, target: self,   selector: (#selector(clearIndicatorLabel)), userInfo: nil, repeats: false)
    }
    
    func sendGarageStatusCommandWith(buttonState: String, gpioNum: Int, indicatorLabel: UILabel) {
        
        let iotDataManager = AWSIoTDataManager.default()
        iotDataManager.publishString("{\"state\":{\"reported\":{\"ON_OFF\":\"\(buttonState)\",\"GPIO\":\(gpioNum)}}}", onTopic:"Garage", qoS:.messageDeliveryAttemptedAtMostOnce)

        timer = Timer.scheduledTimer(timeInterval: 4, target: self,   selector: (#selector(clearIndicatorLabel)), userInfo: nil, repeats: false)
    }
    
    @objc func clearIndicatorLabel() {
        statusLabel.text = ""
    }
    
    func setBackgroundColorBasedOnDistance() {
        self.locationManager.startUpdatingLocation()
        guard let distanceToHome = locationManager.location?.distance(from: homeLocation) else { return }
        self.locationManager.stopUpdatingLocation()
        
        statusLabel.text = "Distance to Home = \(round(distanceToHome*10)/10) meters"
        if distanceToHome > HomeDistanceThresh {
            PanelView.backgroundColor = UIColor(red: CGFloat(255/255.0), green: CGFloat(153/255.0), blue: CGFloat(204/255.0), alpha: CGFloat(1.0))
        }
        else {
            PanelView.backgroundColor = UIColor.lightGray
        }
    }
}
