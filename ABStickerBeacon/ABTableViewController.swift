//
//  ABTableViewController.swift
//  ABStickerBeacon
//
//  Created by gongliang on 16/5/26.
//  Copyright © 2016年 AB. All rights reserved.
//

import UIKit
import CoreBluetooth

@objc class ABSensor: NSObject {
    var name = "absensor"
    var macAddress = ""
    var rssi = 0
    var temperature = 0
    var isRun = false
    var x = 0
    var y = 0
    var z = 0
    var battery = 100
    var measuredPower = -59
    var currentRuntime = 0
    var lastRuntime = 0
    var peripheral: CBPeripheral?
    
    init(name: String, macAddress: String, rssi: Int, temperature: Int, isRun: Bool, x: Int, y: Int, z: Int, battery: Int, measuredPower: Int, peripheral: CBPeripheral) {
        self.name = name
        self.macAddress = macAddress
        self.rssi = rssi
        self.temperature = temperature
        self.isRun = isRun
        self.x = x
        self.y = y
        self.z = z
        self.battery = battery
        self.measuredPower = measuredPower
        self.peripheral = peripheral
        super.init()
    }
}

class ABTableViewController: UITableViewController {
    
    let centralManager: CBCentralManager = CBCentralManager(delegate: nil, queue: nil)
    
    var identifiers = [String]()
    var sensors = [String: ABSensor]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        centralManager.delegate = self
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    @IBAction func refresh(sender: UIBarButtonItem) {
        identifiers.removeAll()
        sensors.removeAll()
        tableView.reloadData()
    }
}

extension ABTableViewController {
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sensors.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("sensorCell", forIndexPath: indexPath)
        
        if let sensor = sensors[identifiers[indexPath.row]] {
            let run = sensor.isRun ? "YES" : "NO"
            cell.textLabel?.text = "\(sensor.name)\nmac:       \(sensor.macAddress.uppercaseString)\nMotion state: \(run)\nTemperature:    \(sensor.temperature) ℃\nx: \(sensor.x)  y: \(sensor.y)  z: \(sensor.z) \nBattery:    \(sensor.battery)%\nMP:     \(sensor.measuredPower)"
            cell.detailTextLabel?.text = "rssi: \(sensor.rssi)"
        }

        return cell
    }
}

extension ABTableViewController: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(central: CBCentralManager) {
        if central.state == .PoweredOn {
            let options = [CBCentralManagerScanOptionAllowDuplicatesKey: false]
            centralManager.scanForPeripheralsWithServices(nil, options: options)
        }
    }
    
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        if let name = peripheral.name where name.hasPrefix("asensor") {
            
            if let data = advertisementData["kCBAdvDataManufacturerData"] as? NSData {
                
                let identifier = peripheral.identifier.UUIDString
                if !identifiers.contains(identifier) {
                    identifiers.append(identifier)
                }
                
                print("===================================================================================================")
                print("data \(data)")

                let macAddressData = data.subdataWithRange(NSMakeRange(2, 6))
                let macAddressString = String(macAddressData.hexadecimalString)
                print("macaddress = \(macAddressString)")
                
                let bytesData = data.subdataWithRange(NSMakeRange(8, 10))
                var bytes = [UInt8](count: bytesData.length, repeatedValue: 0)
                bytesData.getBytes(&bytes, length: bytesData.length)
                
                let sensor = ABSensor(name: peripheral.name ?? "",
                                      macAddress: macAddressString,
                                      rssi: RSSI.integerValue,
                                      temperature: Int(bytes[1]),
                                      isRun: bytes[2] == 1,
                                      x: Int(bytes[3]),
                                      y: Int(bytes[4]),
                                      z: Int(bytes[5]),
                                      battery: Int(bytes[8]),
                                      measuredPower: Int(bytes[9]) - 255,
                                      peripheral: peripheral)
                sensor.currentRuntime = Int(bytes[6])
                sensor.lastRuntime = Int(bytes[7])

                sensors[identifier] = sensor
                tableView.reloadData()
                
                //                print("bytes = \(bytes)")
                /*
                 d200 ccbbaa99b880  02  12  00        ff 05 41  0000      55   c5
                      ___________   __  __  __        __ __ __  ____      __   __
                       macAddress      温度 运动状态    x  y  z   自定义     电 measurepower
                 */
            }
        }
    }
}

extension NSData {
    var hexadecimalString: NSString {
        var bytes = [UInt8](count: length, repeatedValue: 0)
        
        getBytes(&bytes, length: length)
        
        let hexString = NSMutableString()
        for (index, byte) in bytes.enumerate() {
            hexString.appendFormat("%02x", UInt(byte))
            if index < bytes.count - 1 {
                hexString.appendString("-")
            }
        }
        return NSString(string: hexString)
    }
}
