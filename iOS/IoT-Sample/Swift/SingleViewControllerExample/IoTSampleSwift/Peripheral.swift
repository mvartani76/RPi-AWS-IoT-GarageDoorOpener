//
//  Peripheral.swift
//  IoTSampleSwift
//
//  Created by Michael Vartanian on 10/20/20.
//  Copyright © 2020 Amazon. All rights reserved.
//

import Foundation
import UIKit
import CoreBluetooth

class Peripheral: NSObject {

    /// MARK: - Peripheral Parameter services and charcteristics Identifiers

    public static let peripheralParamServiceUUID    = CBUUID.init(string: "6e400001-b5a3-f393-e0a9-e50e24dcca9e")
    public static let toggleGarage1CharacteristicUUID      = CBUUID.init(string: "6e400002-b5a3-f393-e0a9-e50e24dcca9e")
    public static let toggleGarage2CharacteristicUUID      = CBUUID.init(string: "6e400003-b5a3-f393-e0a9-e50e24dcca9e")
    public static let requestGarage1StatusCharacteristicUUID      = CBUUID.init(string: "6e400004-b5a3-f393-e0a9-e50e24dcca9e")
    public static let requestGarage2StatusCharacteristicUUID      = CBUUID.init(string: "6e400005-b5a3-f393-e0a9-e50e24dcca9e")
    public static let txCharacteristicUUID      = CBUUID.init(string: "6e400006-b5a3-f393-e0a9-e50e24dcca9e")
}
