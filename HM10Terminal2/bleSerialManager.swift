//
//  bleSerialManager.swift
//  HM10Terminal2
//
//  Created by Casey Brittain on 8/22/15.
//  Copyright © 2015 Honeysuckle Hardware. All rights reserved.
//

import Foundation
import CoreBluetooth

protocol bleSerialDelegate {
    func searchTimerExpired(controller: AnyObject)
}

class bleSerialManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    var delegate:bleSerialDelegate? = nil
    
    var activeCentralManager = CBCentralManager()
    var activePeripheralManager = CBPeripheralManager()
    var peripheralDevice: CBPeripheral?
    
    // Initialize the activeCentralManagerState
    var activeCentralManagerState: CBCentralManagerState?

    // Search properities.
    private var searchComplete: Bool = false
    var searchTimeoutTimer: NSTimer = NSTimer()
    
    // Device descriptors for discovered devices.
    var discoveredDeviceList: Dictionary<NSUUID, CBPeripheral> = Dictionary()
    private var discoveredDeviceListRSSI: Dictionary<NSUUID, NSNumber> = Dictionary()
    private var discoveredDeviceListAdvertisementData: Dictionary<NSUUID, [String : AnyObject]> = Dictionary()
    private var discoveredDeviceListUUIDString: Dictionary<NSUUID, String> = Dictionary()
    private var discoveredDeviceListNameString: Dictionary<NSUUID, String> = Dictionary()
    

    // Device descriptors for connected device.
    private var connectedPeripheralServices: Array<CBService> = Array()
    private var connectedPeripheralCharacteristics: Array<CBCharacteristic> = Array()
    private var connectedPeripheralCharacteristicsDescriptors: Array<CBDescriptor> = Array()
    
    override init(){
        super.init()
        
        // Set initial state.
        activeCentralManagerState = CBCentralManagerState.Unknown
        // Attach delegate
        activeCentralManager = CBCentralManager(delegate: self, queue:  dispatch_get_main_queue())
    }
    
    func centralManagerDidUpdateState(central: CBCentralManager) {
        
        // Make sure the iOS BLE device state status is updated.
        activeCentralManagerState = central.state
        // Make sure the BLE device is on.
        if central.state == CBCentralManagerState.PoweredOn {
            // Scan for peripherals if BLE is turned on
            central.scanForPeripheralsWithServices(nil, options: nil)
            print("Searching for BLE Devices")
        }
        else {
            // Can have different conditions for all states if needed - print generic message for now
            print("Bluetooth switched off or not initialized")
        }
    }
    
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        
        // Let's get all the information about the discovered devices.
        discoveredDeviceList.updateValue(peripheral, forKey: peripheral.identifier)
        discoveredDeviceListRSSI.updateValue(RSSI, forKey: peripheral.identifier)
        discoveredDeviceListAdvertisementData.updateValue(advertisementData, forKey: peripheral.identifier)
        discoveredDeviceListUUIDString.updateValue(peripheral.identifier.UUIDString, forKey: peripheral.identifier)
        if let name = peripheral.name {
            discoveredDeviceListNameString.updateValue(name, forKey: peripheral.identifier)
        }
    }
    

    // #MARK: Get discovered but unconnected device info
    func getNumberOfDiscoveredDevices()->Int{
        return discoveredDeviceList.count
    }
    
    func getDeviceListAsArray()->Array<NSUUID>{
        let deviceListArray =  Array(discoveredDeviceList.keys)
        return deviceListArray
    }
    
    func getDeviceName(deviceOfInterest: NSUUID)->String{
        let deviceName = discoveredDeviceListNameString[deviceOfInterest]
        if let deviceName = deviceName {
            return deviceName
        }
        else {
            return ""
        }
    }
    
    func getDeviceRSSI(deviceOfInterest: NSUUID)->Int {
        let deviceRSSI = discoveredDeviceListRSSI[deviceOfInterest]
        if let deviceRSSI = deviceRSSI {
            return Int(deviceRSSI)
        }
        else {
            return 0
        }
    }
    
    func getDeviceState()->Int{
        // Provide the raw state of the device.
        return activeCentralManager.state.rawValue
    }


    // #MARK: Search for devices
    func search(targetObject: AnyObject, nameOfCallback: String, timeoutSecs: NSTimeInterval){
        searchComplete = false
        activeCentralManager = CBCentralManager(delegate: self, queue: nil)
        searchTimeoutTimer = NSTimer.scheduledTimerWithTimeInterval(timeoutSecs, target: targetObject, selector: Selector(nameOfCallback), userInfo: nil, repeats: false)
    }
    
    func searchTimerTimeout(){
        searchTimeoutTimer.invalidate()
        searchComplete = true
        printDiscoveredDeviceListInfo()
        delegate!.searchTimerExpired(self)
    }
    
    // #MARK: Connect to device
    func connectToDevice(deviceNSUUID: NSUUID) -> Bool {
        
        if(discoveredDeviceList.isEmpty){
            return false
        }
        else {
            if let deviceToConnect = discoveredDeviceList[deviceNSUUID] {
                activeCentralManager.connectPeripheral(deviceToConnect, options: nil)
            }
        }
        return true
    }
    
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {

        peripheralDevice = peripheral
        peripheralDevice?.delegate = self
        // Look for set services
        
        // If not, do below.
        
        if let peripheralDevice = peripheralDevice {
            peripheralDevice.discoverServices(nil)
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        
        // Look for set characteristics.
        
        // If not, do below.
        
        if let peripheralDevice = peripheralDevice {
            if let serviceArray = peripheralDevice.services {
                for service in serviceArray {
                    connectedPeripheralServices.append(service)
                    peripheralDevice.discoverCharacteristics(nil, forService: service)
                }
            }
        }
        
        
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {

        // Look for set characteristics descriptors.
        
        // If not, do below.
        
        if let peripheralDevice = peripheralDevice {
            if let characteristicsArray = service.characteristics {
                for characteristic in characteristicsArray {
                    connectedPeripheralCharacteristics.append(characteristic)
                    peripheralDevice.discoverDescriptorsForCharacteristic(characteristic)
                }
            }
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverDescriptorsForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        if let  descriptorsArray = characteristic.descriptors {
            for descriptors in descriptorsArray {
                connectedPeripheralCharacteristicsDescriptors.append(descriptors)
            }
        }
        
        // End of the line.
    }
    
    // #MARK: Debug info.
    func printDiscoveredDeviceListInfo(){
        // Check to make sure we're done searching, then print the all devices info.
        if(searchComplete){
            for ID in self.discoveredDeviceList.keys {
                if let name = self.discoveredDeviceListNameString[ID]{
                    print("Device UUID: \(name)")
                }
                if let thisUUID = self.discoveredDeviceListUUIDString[ID] {
                    print("\t\tUUID: \(String(thisUUID))")
                }
                if let RSSI = self.discoveredDeviceListRSSI[ID] {
                    print("\t\tRRSI: \(RSSI)")
                }
            }
        }
        else{
            print("Search for devices is not yet complete")
        }
        
    }

}