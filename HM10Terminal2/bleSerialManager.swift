//
//  bleSerialManager.swift
//  HM10Terminal2
//
//  Created by Casey Brittain on 8/22/15.
//  Copyright © 2015 Honeysuckle Hardware. All rights reserved.
//

import Foundation
import CoreBluetooth

@objc protocol bleSerialDelegate {
    optional func searchTimerExpired(controller: AnyObject)
    optional func deviceStatusChanged(controller: AnyObject)
}



class bleSerialManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    // Delegate for search updates.
    var delegate:bleSerialDelegate? = nil
    
    var activeCentralManager = CBCentralManager()
    var activePeripheralManager = CBPeripheralManager()
    var peripheralDevice: CBPeripheral?
    var lastConnectedPeripheralNSUUID: NSUUID?

    // Search properities.
    private var searchComplete: Bool = false
    var searchTimeoutTimer: NSTimer = NSTimer()
    var reconnectTimer: NSTimer = NSTimer()
    
    // Device descriptors for discovered devices.
    var discoveredDeviceList: Dictionary<NSUUID, CBPeripheral> = Dictionary()
    private var discoveredDeviceListRSSI: Dictionary<NSUUID, NSNumber> = Dictionary()
    private var discoveredDeviceListAdvertisementData: Dictionary<NSUUID, [String : AnyObject]> = Dictionary()
    private var discoveredDeviceListUUIDString: Dictionary<NSUUID, String> = Dictionary()
    private var discoveredDeviceListNameString: Dictionary<NSUUID, String> = Dictionary()
    
    // Device descriptors for connected device.
    private var connectedPeripherals: Dictionary<NSUUID, CBPeripheral> = Dictionary()
    private var connectedPeripheralServices: Array<CBService> = Array()
    private var connectedPeripheralCharacteristics: Array<CBCharacteristic> = Array()
    private var connectedPeripheralCharacteristicsDescriptors: Array<CBDescriptor> = Array()
    
    enum masterDeviceStates: Int {
        case Unknown = 0
        case Resetting
        case Unsupported
        case Unauthorized
        case PoweredOff
        case PoweredOn
        case Reconnecting
        
    }
    
    // Initialize the activeCentralManagerState
    private(set) var activeCentralManagerState: Int = 0
    
    // Behavioral options.
        // Connections limit.
        private var connectionsLimit = 1

        // Reconnect
        private var automaticReconnectOnDisconnect = true
        private var timeBeforeAttemptingReconnectOnDisconnect = 1.0
        private var numberOfRetriesOnDisconnect = 3
    
        private var automaticConnectionRetryOnFail = true
        private var timeBeforeAttemptingReconnectOnConnectionFail = 1.0
        private var numberOfRetriesAfterConnectionFail = 3

        private var retryIndexOnDisconnect = 0
        private var retryIndexOnFail = 0
    
    
    override init(){
        super.init()
        
        // Set initial state.
//        activeCentralManagerState = CBCentralManagerState.Unknown
        // Attach delegate
        activeCentralManager = CBCentralManager(delegate: self, queue:  dispatch_get_main_queue())
    }
    
    // #MARK: Behavior defining methods.
    func setMutipleConnections(connectionLimit: Int){
        connectionsLimit = connectionLimit
    }
    
    func setAutomaticReconnectOnDisconnect(flag: Bool, tries: Int, timeBetweenTries: Double){
        automaticReconnectOnDisconnect = flag
        timeBeforeAttemptingReconnectOnDisconnect = timeBetweenTries
        numberOfRetriesOnDisconnect = tries
    }
    
    func setRetryConnectAfterFail(flag: Bool, tries: Int, timeBetweenTries: Double){
        automaticConnectionRetryOnFail = flag
        timeBeforeAttemptingReconnectOnConnectionFail = timeBetweenTries
        numberOfRetriesAfterConnectionFail = tries
    }
    

    // #MARK: Central Manager init.
    func centralManagerDidUpdateState(central: CBCentralManager) {
        
        // Make sure the iOS BLE device state status is updated.
        activeCentralManagerState = central.state.rawValue
        // Make sure the BLE device is on.
        switch activeCentralManager.state {
        case CBCentralManagerState.Unknown:
            print("Unknown")
            activeCentralManagerState = central.state.rawValue
            break
        case CBCentralManagerState.Resetting:
            print("Resetting")
            break
        case CBCentralManagerState.Unsupported:
            print("Unsupported")
            break
        case CBCentralManagerState.Unauthorized:
            print("Unauthorized")
            break
        case CBCentralManagerState.PoweredOff:
            print("PoweredOff")
            break
        case CBCentralManagerState.PoweredOn:
            // Scan for peripherals if BLE is turned on
            central.scanForPeripheralsWithServices(nil, options: nil)
            print("Searching for BLE Devices")
            break
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
    
    func getSortedArraysBasedOnRSSI()-> (nsuuids: Array<NSUUID>, rssies: Array<NSNumber>){

        // Bubble-POP! :)
        var rssies = Array(discoveredDeviceListRSSI.values)
        var nsuuids = Array(discoveredDeviceListRSSI.keys)
        let countOfKeys = discoveredDeviceListRSSI.keys.count
        
        var x = 0
        var y = 0
        //var bubblePop = true
        
        while(x < countOfKeys)
        {
            while(y < countOfKeys - 1)
            {
                if(Int(rssies[y]) < Int(rssies[y+1]))
                {
                    let temp1 = Int(rssies[y+1])
                    let temp2 = nsuuids[y+1]

                    rssies[y+1] = Int(rssies[y]);
                    nsuuids[y+1] = nsuuids[y]
                    
                    rssies[y] = temp1
                    nsuuids[y] = temp2
                }
                y++
            }
            x++
        }
        return (nsuuids, rssies)
    }
    
    
    func getDeviceState()->Int{
        // Provide the raw state of the device.
        return activeCentralManager.state.rawValue
    }


    // #MARK: Search for devices
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
    
    func search(targetObject: AnyObject, nameOfCallback: String, timeoutSecs: NSTimeInterval){
        searchComplete = false
        clearDiscoveredDevices()
        activeCentralManager = CBCentralManager(delegate: self, queue: nil)
        searchTimeoutTimer = NSTimer.scheduledTimerWithTimeInterval(timeoutSecs, target: targetObject, selector: Selector(nameOfCallback), userInfo: nil, repeats: false)
    }
    
    func searchTimerTimeout(){
        searchTimeoutTimer.invalidate()
        searchComplete = true
        printDiscoveredDeviceListInfo()
        if let delegateSearchTimerExpired = delegate?.searchTimerExpired?(self){
//            delegateSearchTimerExpired = s
        }
    }
    
    // #MARK: Connect to device
    func connectToDevice(deviceNSUUID: NSUUID) -> Bool {

        // Remember NSUUID
        lastConnectedPeripheralNSUUID = deviceNSUUID
        
        // Check if if we have discovered anything, if so, make sure we are not already connected.
        if(discoveredDeviceList.isEmpty || alreadyConnected(deviceNSUUID)){
            print("Already connected, silly")
            return false
        }
        else {
            if(connectedPeripherals.count < connectionsLimit){
                if let deviceToConnect = discoveredDeviceList[deviceNSUUID] {
                    activeCentralManager.connectPeripheral(deviceToConnect, options: nil)
                }
            }
            else
            {
                print("Too many connections")
            }
            if(automaticReconnectOnDisconnect){
                retryIndexOnDisconnect = 0
            }
        }
        return true
    }
    
    func alreadyConnected(deviceNSUUID: NSUUID) -> Bool {
        // Checks if we are already connected to a device.
        return connectedPeripherals[deviceNSUUID] != nil
    }
    
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        
        // Add peripheral to connectedPeripheral dictionary.
        connectedPeripherals.updateValue(peripheral, forKey: peripheral.identifier)
        hm10serialManager.printConnectedDevices()
        
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
    
    func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        // If we fail to connect, don't remember this device.

        if(automaticConnectionRetryOnFail && retryIndexOnFail < numberOfRetriesAfterConnectionFail){
            reconnectTimer = NSTimer.scheduledTimerWithTimeInterval(timeBeforeAttemptingReconnectOnConnectionFail, target: self, selector: Selector("reconnectTimerExpired"), userInfo: nil, repeats: false)
        }
        else {
            lastConnectedPeripheralNSUUID = nil
        }
    }
    
    func clearDiscoveredDevices(){
        // Device descriptors for discovered devices.
        discoveredDeviceList.removeAll()
        discoveredDeviceListRSSI.removeAll()
        discoveredDeviceListAdvertisementData.removeAll()
        discoveredDeviceListUUIDString.removeAll()
        discoveredDeviceListNameString.removeAll()
    }
    
    // #MARK: Connection Lost.
    func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        
        // If connection is lost, remove it from the connected device dictionary.
        connectedPeripherals.removeValueForKey(peripheral.identifier)
        print("Lost connection to: \(peripheral.identifier)")
        
        if(automaticReconnectOnDisconnect){
            activePeripheralManager.state
            reconnectTimer = NSTimer.scheduledTimerWithTimeInterval(timeBeforeAttemptingReconnectOnDisconnect, target: self, selector: Selector("reconnectTimerExpired"), userInfo: nil, repeats: false)
        }
        
    }
    
    func reconnectTimerExpired(){
        if let lastConnectedPeripheralNSUUID = lastConnectedPeripheralNSUUID {
            connectToDevice(lastConnectedPeripheralNSUUID)
        }
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
    
    func printConnectedDevices(){
        print("Number of connected devices: \(connectedPeripherals.count)")
    }

    // End of bleSerialManager class.
}



extension CBPeripheralManager {

    // This adds a state feature to the peripheralManager.
    enum State: Int {
        case disconnected = 0
        case connected
        case attemptingToReconnect
    }
}