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

class PublishViewController: UIViewController {

    @IBOutlet weak var publishSlider: UISlider!

    @IBOutlet weak var publishButton: UIButton!
    
    @IBOutlet weak var GarageON:
        UIButton!
    
    @IBOutlet weak var GarageOFF:
        UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func ButtonPressed(_ sender: UIButton) {
        
        let iotDataManager = AWSIoTDataManager.default()
            
        iotDataManager?.publishString("{\"state\":{\"reported\":{\"ON_OFF\":\"TOGGLE\",\"GPIO\":17}}}", onTopic:"Garage", qoS:.messageDeliveryAttemptedAtMostOnce)
    }
        
    @IBAction func ONGarageButtonPressed() {
        
        let iotDataManager = AWSIoTDataManager.default()
        iotDataManager?.publishString("{\"state\":{\"reported\":{\"ON_OFF\":\"ON\",\"GPIO\":17}}}", onTopic:"Garage", qoS:.messageDeliveryAttemptedAtMostOnce)
    }

    @IBAction func OFFGarageButtonPressed() {
        
        let iotDataManager = AWSIoTDataManager.default()
        iotDataManager?.publishString("{\"state\":{\"reported\":{\"ON_OFF\":\"OFF\",\"GPIO\":17}}}", onTopic:"Garage", qoS:.messageDeliveryAttemptedAtMostOnce)
    }
    
    @IBAction func sliderValueChanged(_ sender: UISlider) {
        print("\(sender.value)")

        let iotDataManager = AWSIoTDataManager.default()
        let tabBarViewController = tabBarController as! IoTSampleTabBarController

        iotDataManager?.publishString("\(sender.value)", onTopic:tabBarViewController.topic, qoS:.messageDeliveryAttemptedAtMostOnce)
    }
}
