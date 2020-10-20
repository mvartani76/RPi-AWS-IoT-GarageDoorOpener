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
import AWSMobileClient
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
    
    @objc var iotDataManager: AWSIoTDataManager!;
    @objc var iotManager: AWSIoTManager!;
    @objc var iot: AWSIoT!
    @objc var connected = false;
    
    var mqttStatus: String = "Disconnected"
    var topic: String = "Garage"
    
    var timer = Timer()
    
    func mqttEventCallback( _ status: AWSIoTMQTTStatus )
    {
        DispatchQueue.main.async {
            print("connection status = \(status.rawValue)")
            switch(status)
            {
                case .connecting:
                    self.mqttStatus = "Connecting..."
                    print( self.mqttStatus )
                    self.statusLabel.text = self.mqttStatus

                case .connected:
                    self.mqttStatus = "Connected"
                    print( self.mqttStatus )

                    let uuid = UUID().uuidString;
                    let defaults = UserDefaults.standard
                    let certificateId = defaults.string( forKey: "certificateId")

                    self.statusLabel.text = "Using certificate:\n\(certificateId!)\n\n\nClient ID:\n\(uuid)"

                case .disconnected:
                    self.mqttStatus = "Disconnected"
                    print( self.mqttStatus )
                    self.statusLabel.text = nil

                case .connectionRefused:
                    self.mqttStatus = "Connection Refused"
                    print( self.mqttStatus )
                    self.statusLabel.text = self.mqttStatus

                case .connectionError:
                    self.mqttStatus = "Connection Error"
                    print( self.mqttStatus )
                    self.statusLabel.text = self.mqttStatus

                case .protocolError:
                    self.mqttStatus = "Protocol Error"
                    print( self.mqttStatus )
                    self.statusLabel.text = self.mqttStatus

                default:
                    self.mqttStatus = "Unknown State"
                    print("unknown state: \(status.rawValue)")
                    self.statusLabel.text = self.mqttStatus
            }

            NotificationCenter.default.post( name: Notification.Name(rawValue: "connectionStatusChanged"), object: self )
        }
    }
    
    func connectIoT() {
        if (connected == false)
            {
                let defaults = UserDefaults.standard
                var certificateId = defaults.string( forKey: "certificateId")

                if (certificateId == nil)
                {
                    DispatchQueue.main.async {
                        self.statusLabel.text = "No identity available, searching bundle..."
                    }

                    // No certificate ID has been stored in the user defaults; check to see if any .p12 files
                    // exist in the bundle.
                    let myBundle = Bundle.main
                    let myImages = myBundle.paths(forResourcesOfType: "p12" as String, inDirectory:nil)
                    let uuid = UUID().uuidString;
                    
                    if (myImages.count > 0) {
                        // At least one PKCS12 file exists in the bundle.  Attempt to load the first one
                        // into the keychain (the others are ignored), and set the certificate ID in the
                        // user defaults as the filename.  If the PKCS12 file requires a passphrase,
                        // you'll need to provide that here; this code is written to expect that the
                        // PKCS12 file will not have a passphrase.
                        if let data = try? Data(contentsOf: URL(fileURLWithPath: myImages[0])) {
                            DispatchQueue.main.async {
                                self.statusLabel.text = "found identity \(myImages[0]), importing..."
                            }
                            if AWSIoTManager.importIdentity( fromPKCS12Data: data, passPhrase:"", certificateId:myImages[0]) {
                                // Set the certificate ID and ARN values to indicate that we have imported
                                // our identity from the PKCS12 file in the bundle.
                                defaults.set(myImages[0], forKey:"certificateId")
                                defaults.set("from-bundle", forKey:"certificateArn")
                                DispatchQueue.main.async {
                                    self.statusLabel.text = "Using certificate: \(myImages[0]))"
                                    self.iotDataManager.connect( withClientId: uuid, cleanSession:true, certificateId:myImages[0], statusCallback: self.mqttEventCallback)
                                }
                            }
                        }
                    }

                    certificateId = defaults.string( forKey: "certificateId")
                    if (certificateId == nil) {
                        DispatchQueue.main.async {
                            self.statusLabel.text = "No identity found in bundle, creating one..."
                        }

                        // Now create and store the certificate ID in NSUserDefaults
                        let csrDictionary = [ "commonName":CertificateSigningRequestCommonName, "countryName":CertificateSigningRequestCountryName, "organizationName":CertificateSigningRequestOrganizationName, "organizationalUnitName":CertificateSigningRequestOrganizationalUnitName ]

                        self.iotManager.createKeysAndCertificate(fromCsr: csrDictionary, callback: {  (response ) -> Void in
                            if (response != nil)
                            {
                                defaults.set(response?.certificateId, forKey:"certificateId")
                                defaults.set(response?.certificateArn, forKey:"certificateArn")
                                certificateId = response?.certificateId
                                print("response: [\(String(describing: response))]")

                                let attachPrincipalPolicyRequest = AWSIoTAttachPrincipalPolicyRequest()
                                attachPrincipalPolicyRequest?.policyName = PolicyName
                                attachPrincipalPolicyRequest?.principal = response?.certificateArn

                                // Attach the policy to the certificate
                            self.iot.attachPrincipalPolicy(attachPrincipalPolicyRequest!).continueWith (block: { (task) -> AnyObject? in
                                    if let error = task.error {
                                        print("failed: [\(error)]")
                                    }
                                    print("result: [\(String(describing: task.result))]")

                                    // Connect to the AWS IoT platform
                                    if (task.error == nil)
                                    {
                                        DispatchQueue.main.asyncAfter(deadline: .now()+2, execute: {
                                            self.statusLabel.text = "Using certificate: \(certificateId!)"
                                            self.iotDataManager.connect( withClientId: uuid, cleanSession:true, certificateId:certificateId!, statusCallback: self.mqttEventCallback)
                                        })
                                    }
                                    return nil
                                })
                            }
                            else
                            {
                                DispatchQueue.main.async {
                                    self.statusLabel.text = "Unable to create keys and/or certificate."
                                }
                            }
                        } )
                    }
                }
                else
                {
                    let uuid = UUID().uuidString;

                    // Connect to the AWS IoT service
                    iotDataManager.connect( withClientId: uuid, cleanSession:true, certificateId:certificateId!, statusCallback: mqttEventCallback)
                }
            }
            else
            {
                self.statusLabel.text = "Disconnecting..."

                DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                    self.iotDataManager.disconnect();
                    DispatchQueue.main.async {
                        self.connected = false
                    }
                }
            }
            // clear status label
            DispatchQueue.main.asyncAfter(deadline: .now()+3, execute: {
                self.statusLabel.text = ""
            })
        }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        self.locationManager.requestWhenInUseAuthorization()
        
        // Initialize AWSMobileClient for authorization
        AWSMobileClient.default().initialize { (userState, error) in
            guard error == nil else {
                print("Failed to initialize AWSMobileClient. Error: \(error!.localizedDescription)")
                return
            }
            print("AWSMobileClient initialized.")
        }

        // Init IOT
        let iotEndPoint = AWSEndpoint(urlString: IOT_ENDPOINT)

        // Configuration for AWSIoT control plane APIs
        let iotConfiguration = AWSServiceConfiguration(region: AWSRegion, credentialsProvider: AWSMobileClient.default())

        // Configuration for AWSIoT data plane APIs
        let iotDataConfiguration = AWSServiceConfiguration(region: AWSRegion,
                                                           endpoint: iotEndPoint,
                                                           credentialsProvider: AWSMobileClient.default())
        AWSServiceManager.default().defaultServiceConfiguration = iotConfiguration

        iotManager = AWSIoTManager.default()
        iot = AWSIoT.default()

        AWSIoTDataManager.register(with: iotDataConfiguration!, forKey: ASWIoTDataManager)
        iotDataManager = AWSIoTDataManager(forKey: ASWIoTDataManager)

        connectIoT()
        
        iotDataManager.subscribe(toTopic: topic, qoS: .messageDeliveryAttemptedAtLeastOnce, messageCallback: {
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
                        DispatchQueue.main.sync {
                            // Update the statusLabel with the garage state
                            self.statusLabel.text = garageState
                        }
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
        sender.pulsate()
        sendGarageToggleCommandWith(buttonState: "TOGGLE", gpioNum: GarageTOGGLEButton1_GPIO, homeDistanceThresh: HomeDistanceThresh, indicatorLabel: statusLabel)
    }
    
    @IBAction func wasGarageTOGGLEButton2Pressed(_ sender: UIButton) {
        sender.pulsate()
        sendGarageToggleCommandWith(buttonState: "TOGGLE", gpioNum: GarageTOGGLEButton2_GPIO, homeDistanceThresh: HomeDistanceThresh, indicatorLabel: statusLabel)
    }
    
    @IBAction func wasRequestSTATUSButtonPressed(_ sender: UIButton) {
        sender.shrink()
        sendGarageStatusCommandWith(buttonState: "REQUEST_STATUS", gpioNum: RequestSTATUSButton_GPIO, indicatorLabel: statusLabel)
        //sender.expand()
    }
    
    func sendGarageToggleCommandWith(buttonState: String, gpioNum: Int, homeDistanceThresh: Double, indicatorLabel: UILabel) {
        
        guard let distanceToHome = locationManager.location?.distance(from: homeLocation) else { return }
        
        if distanceToHome < homeDistanceThresh {
            let iotDataManager = AWSIoTDataManager(forKey: ASWIoTDataManager)
            iotDataManager.publishString("{\"state\":{\"reported\":{\"ON_OFF\":\"\(buttonState)\",\"GPIO\":\(gpioNum)}}}", onTopic:"Garage", qoS:.messageDeliveryAttemptedAtLeastOnce)
            indicatorLabel.text = "Within Distance Threshold, passed \(buttonState) to \(gpioNum)"
        }
        else {
            indicatorLabel.text = "Outside of Distance Threshold. Garage command not sent."
        }
        
        timer = Timer.scheduledTimer(timeInterval: 4, target: self,   selector: (#selector(clearIndicatorLabel)), userInfo: nil, repeats: false)
    }
    
    func sendGarageStatusCommandWith(buttonState: String, gpioNum: Int, indicatorLabel: UILabel) {
        
        let iotDataManager = AWSIoTDataManager(forKey: ASWIoTDataManager)
        iotDataManager.publishString("{\"state\":{\"reported\":{\"ON_OFF\":\"\(buttonState)\",\"GPIO\":\(gpioNum)}}}", onTopic:"Garage", qoS:.messageDeliveryAttemptedAtLeastOnce)

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
