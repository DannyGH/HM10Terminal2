//
//  bleSerialManager.swift
//  HM10Terminal2
//
//  Created by Casey Brittain on 8/22/15.
//  Copyright © 2015 Honeysuckle Hardware. All rights reserved.
//

import Foundation
import CoreBluetooth
//import CoreLocation





// Things to add
// 0. Finish advertisement data.  Do hell knows what with iBeacon crap.
// 1. Running in the background options.
// 2. Alert view for warning about losing connections.
// 3. Serial Buffer.
// 4. Serial data recieved optional delegate.
// 5. Create a connectToLastPeripheralConnected()
// 6.   // Add service array and getter methods
        // Add characteristic array and getter methods
        // Add characteristic descriptors array and getter methods
// 7. Add option to connect search for specific device, services, characteristics, and descriptors.
// 8. Save a white list of connections.  Provide option to reconnect on opening app.
// 9. Change searchTimerExpire and searchTimerExpireD so namespaces don't confuse.





@objc protocol bleSerialDelegate {
    optional func searchTimerExpired()
    optional func deviceStatusChanged(nsuuidOfDevice: NSUUID, deviceState: Int)
    optional func connectedToDevice()
}

class bleSerialManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
//    let locationManager = CLLocationManager()
//    var region: CLBeaconRegion?

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
    private var discoveredDeviceList: Dictionary<NSUUID, CBPeripheral> = Dictionary()
    private var discoveredDeviceListRSSI: Dictionary<NSUUID, NSNumber> = Dictionary()
    private var discoveredDeviceListAdvertisementData: Dictionary<NSUUID, [String : AnyObject]> = Dictionary()
    private var discoveredDeviceListUUIDString: Dictionary<NSUUID, String> = Dictionary()
    private var discoveredDeviceListNameString: Dictionary<NSUUID, String> = Dictionary()


    // Discovered device advertisement data.
    private var discoveredDevicekCBAdvDataManufacturerData: Dictionary<NSUUID, AnyObject> = Dictionary()
    private var discoveredDevicekCBAdvDataIsConnectable: Dictionary<NSUUID, AnyObject> = Dictionary()
    private var discoveredDevicekCBAdvDataServiceUUIDs: Dictionary<NSUUID, AnyObject> = Dictionary()
    private var discoveredDevicekCBAdvDataTxPowerLevel: Dictionary<NSUUID, AnyObject> = Dictionary()
    private var discoveredDevicekCBAdvDataServiceData: Dictionary<NSUUID, AnyObject> = Dictionary()
    private var discoveredDevicekCBAdvSolicitedServiceUUID: Dictionary<NSUUID, AnyObject> = Dictionary()
    private var discoveredDevicekCBAdvDataLocalName: Dictionary<NSUUID, AnyObject> = Dictionary()
    
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
    
    enum deviceState {
        
        // Finish populating this with all states
        // This is meant to be a preperation for a
        // state machine method.  It will be addition
        // to all the callback methods; putting them
        // all in one place.
        case unknown
        case connectedState
        case disconnectedState
    }
    
    let state = deviceState.unknown
    
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
    
    // Flags
    var purposefulDisconnect = false
    
    override init(){
        super.init()
        
        // Set initial state.
//        activeCentralManagerState = CBCentralManagerState.Unknown
        // Attach delegate
        activeCentralManager = CBCentralManager(delegate: self, queue:  dispatch_get_main_queue())
        
        
        
//        if let proximityUUID = NSUUID(UUIDString: "74278BDA-B644-4520-8F0C-720EAF059935") { // generated using uuidgen tool
//            
//            self.region = CLBeaconRegion(proximityUUID: proximityUUID, identifier: "HMSoft")
//            if let region = self.region {
//                locationManager.delegate = self
//                
//                if (CLLocationManager.authorizationStatus() != CLAuthorizationStatus.AuthorizedWhenInUse) {
//                    locationManager.requestWhenInUseAuthorization()
//                }
//                
//                locationManager.startRangingBeaconsInRegion(region)
//            }
//        }
    }

//    func locationManager(manager: CLLocationManager, didRangeBeacons beacons: [CLBeacon], inRegion region: CLBeaconRegion) {
//        print(beacons)    
//    }

    
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
    func getdiscoveredDeviceDictionary()->Dictionary<NSUUID, CBPeripheral>{
        return discoveredDeviceList
    }
    
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
    
    func getDeviceUUIDAsString(deviceOfInterest: NSUUID)->String{
        let deviceUUIDasString = discoveredDeviceListUUIDString[deviceOfInterest]
        if let deviceUUIDasString = deviceUUIDasString {
            return deviceUUIDasString
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
    
    func getAdvDeviceConnectable(deviceOfInterest: NSUUID)->Bool{
        if let discoveredDevicekCBAdvDataIsConnectable = discoveredDevicekCBAdvDataIsConnectable[deviceOfInterest] {
            let connectableFlag = discoveredDevicekCBAdvDataIsConnectable as? Bool
            if let connectableFlag = connectableFlag {
                return connectableFlag
            }
        }
        return false
    }
    
    func getAdvDeviceName(deviceOfInterest: NSUUID)->String{
        if let discoveredDevicekCBAdvDataLocalName = discoveredDevicekCBAdvDataLocalName[deviceOfInterest] {
            let nameAsString = discoveredDevicekCBAdvDataLocalName as? String
            if let nameAsString = nameAsString {
                return nameAsString
            }
        }
        return ""
    }
    
    
    func getAdvDeviceManufactureData(deviceOfInterest: NSUUID)->String{
        if let discoveredDevicekCBAdvDataManufacturerData = discoveredDevicekCBAdvDataManufacturerData[deviceOfInterest] {
            let data = discoveredDevicekCBAdvDataManufacturerData as? NSData
            if let data = data {
                let dataString = NSString(data: data, encoding: NSUTF16StringEncoding) as? String
                if let dataString = dataString {
                    return dataString
                }
            }
        }
        return ""
    }

    func getAdvDeviceServiceData(deviceOfInterest: NSUUID) -> Array<String>{
        if let discoveredDevicekCBAdvDataServiceData = discoveredDevicekCBAdvDataServiceData[deviceOfInterest] {
            let dictionaryCast = discoveredDevicekCBAdvDataServiceData as? Dictionary<CBUUID, NSData>
            var cbuuidAsStringArray: Array<String> = []
            if let dictionaryCast = dictionaryCast {
                for CBUUID in dictionaryCast.values {
                    let cbuuidString = NSString(data: CBUUID, encoding: NSUTF16StringEncoding)
                    if let cbuuidString = cbuuidString {
                        cbuuidAsStringArray.append(cbuuidString as String)
                    }
                }
                return cbuuidAsStringArray
            }
        }
        return [""]
    }

    func getAdvDeviceServiceUUIDasNSArray(deviceOfInterest: NSUUID)->NSArray{
        if let discoveredDevicekCBAdvDataServiceUUIDs = discoveredDevicekCBAdvDataServiceUUIDs[deviceOfInterest] {
            let discoveredDevicekCBAdvDataServiceUUIDStrings = discoveredDevicekCBAdvDataServiceUUIDs as? NSArray
            if let discoveredDevicekCBAdvDataServiceUUIDStrings = discoveredDevicekCBAdvDataServiceUUIDStrings
            {
                if(discoveredDevicekCBAdvDataServiceUUIDs.count > 0){
                    return discoveredDevicekCBAdvDataServiceUUIDStrings
                }
                else {
                    return []
                }
            }
        }
        return []
    }
    
    

    func getAdvTxPowerLevel(deviceOfInterest: NSUUID)->Int{
        if let discoveredDevicekCBAdvDataTxPowerLevel = discoveredDevicekCBAdvDataTxPowerLevel[deviceOfInterest] {
            let txPowerLevelInt = discoveredDevicekCBAdvDataTxPowerLevel as? Int
            if let txPowerLevelInt = txPowerLevelInt
            {
                return txPowerLevelInt
            }
        }
        return 0
    }
    
    func getAdvSolicitedUUID(deviceOfInterest: NSUUID)->NSArray?{
        if let discoveredDevicekCBAdvSolicitedServiceUUID = discoveredDevicekCBAdvSolicitedServiceUUID[deviceOfInterest] {
            let solicitedUUID = discoveredDevicekCBAdvSolicitedServiceUUID as? NSArray
            if let solicitedUUID = solicitedUUID
            {
                if(solicitedUUID.count > 0){
                    return solicitedUUID
                }
                else {
                    return []
                }
            }
        }
        return []
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
        
        // Advertising data.
        let AdvertisementDataIsConnectable = advertisementData[CBAdvertisementDataIsConnectable]
        if let AdvertisementDataIsConnectable = AdvertisementDataIsConnectable {
            discoveredDevicekCBAdvDataIsConnectable.updateValue(AdvertisementDataIsConnectable, forKey: peripheral.identifier)
        }
        else
        {
            print("Nil found unwrapping AdvertisementDataIsConnectable")
        }


        let AdvertisementDataManufacturerDataKey = advertisementData[CBAdvertisementDataManufacturerDataKey]
        if let AdvertisementDataManufacturerDataKey = AdvertisementDataManufacturerDataKey{
            discoveredDevicekCBAdvDataManufacturerData.updateValue(AdvertisementDataManufacturerDataKey, forKey: peripheral.identifier)
        }
        else
        {
            print("Nil found unwrapping AdvertisementDataManufacturerDataKey")
        }


        let AdvertisementDataServiceDataKey = advertisementData[CBAdvertisementDataServiceDataKey] as? Dictionary<CBUUID, NSData>
        if let AdvertisementDataServiceDataKey = AdvertisementDataServiceDataKey {
            discoveredDevicekCBAdvDataServiceData.updateValue(AdvertisementDataServiceDataKey, forKey: peripheral.identifier)
        }
        else
        {
            print("Nil found unwrapping AdvertisementDataServiceDataKey")
        }

        
        let AdvertisementDataLocalNameKey = advertisementData[CBAdvertisementDataLocalNameKey]
        if let AdvertisementDataLocalNameKey = AdvertisementDataLocalNameKey {
            discoveredDevicekCBAdvDataLocalName.updateValue(AdvertisementDataLocalNameKey, forKey: peripheral.identifier)
        }
        else
        {
            print("Nil found unwrapping AdvertisementDataLocalNameKey")
        }

        let AdvertisementDataTxPowerLevelKey = advertisementData[CBAdvertisementDataTxPowerLevelKey]
        if let AdvertisementDataTxPowerLevelKey = AdvertisementDataTxPowerLevelKey{
            discoveredDevicekCBAdvDataTxPowerLevel.updateValue(AdvertisementDataTxPowerLevelKey, forKey: peripheral.identifier)
        }
        else
        {
            print("Nil found unwrapping AdvertisementDataTxPowerLevelKey")
        }
        
        let AdvertisementDataServiceUUIDsKey = advertisementData[CBAdvertisementDataServiceUUIDsKey]
        if let AdvertisementDataServiceUUIDsKey = AdvertisementDataServiceUUIDsKey {
            discoveredDevicekCBAdvDataServiceUUIDs.updateValue(AdvertisementDataServiceUUIDsKey, forKey: peripheral.identifier)
        } else
        {
            print("Nil found unwrapping AdvertisementDataServiceUUIDsKey")
        }

        let AdvertisementDataSolicitedServiceUUIDsKey = advertisementData[CBAdvertisementDataSolicitedServiceUUIDsKey]
        if let AdvertisementDataSolicitedServiceUUIDsKey = AdvertisementDataSolicitedServiceUUIDsKey {
            discoveredDevicekCBAdvSolicitedServiceUUID.updateValue(AdvertisementDataSolicitedServiceUUIDsKey, forKey: peripheral.identifier)
        } else {
            print("Nil found unwrapping AdvertisementDataSolicitedServiceUUIDsKey")
        }
        
        



        // Clear any connections.  (Strangely, if a search is initiated, all devices are disconnected without
        // didDisconnectPeripheral() being called.
        connectedPeripheralServices.removeAll()
        connectedPeripheralCharacteristics.removeAll()
        connectedPeripheralCharacteristicsDescriptors.removeAll()
        
//        print(CBAdvertisementDataLocalNameKey)
        
//        print(advertisementData)
        
        if let name = peripheral.name {
            discoveredDeviceListNameString.updateValue(name, forKey: peripheral.identifier)
        }
    }
    
    func search(timeoutSecs: NSTimeInterval){
        searchComplete = false
        clearDiscoveredDevices()
        // Strange.  If a search for peripherals is initiated it cancels all connections
        // without firing didDisconnectPeripheral.  This compensates.
        clearConnectedDevices()
        activeCentralManager = CBCentralManager(delegate: self, queue: nil)
        searchTimeoutTimer = NSTimer.scheduledTimerWithTimeInterval(timeoutSecs, target: self, selector: Selector("searchTimerExpire"), userInfo: nil, repeats: false)
    }
    
    func searchTimerExpire(){
        searchTimeoutTimer.invalidate()
        searchComplete = true
        printDiscoveredDeviceListInfo()
        if let searchTimerExpired = delegate?.searchTimerExpired?(){
            searchTimerExpired
        }
        else {
            // THROW ERROR
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
                else {
                    return false
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
        
        if let connectedToDevice = delegate?.connectedToDevice?(){
            connectedToDevice
        }
        else {
        
            // Handle if no delegate is setup.
            
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

    func clearDiscoveredDevicesAdvertisementData(){
        connectedPeripherals.removeAll()
        connectedPeripheralServices.removeAll()
        connectedPeripheralCharacteristics.removeAll()
        connectedPeripheralCharacteristicsDescriptors.removeAll()
        
    }

    func clearConnectedDevices(){
        // Clear connected devices
        connectedPeripherals.removeAll()
        connectedPeripheralServices.removeAll()
        connectedPeripheralCharacteristics.removeAll()
        connectedPeripheralCharacteristicsDescriptors.removeAll()
    }

    
    // #MARK: Connection Lost.
    func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        
        // If connection is lost, remove it from the connected device dictionary.
        connectedPeripherals.removeValueForKey(peripheral.identifier)
        print("Lost connection to: \(peripheral.identifier)")
        
        if(automaticReconnectOnDisconnect && purposefulDisconnect == false){
            activePeripheralManager.state
            reconnectTimer = NSTimer.scheduledTimerWithTimeInterval(timeBeforeAttemptingReconnectOnDisconnect, target: self, selector: Selector("reconnectTimerExpired"), userInfo: nil, repeats: false)
        }
        else {
            if let deviceStatusChanged = delegate?.deviceStatusChanged?(peripheral.identifier, deviceState: deviceState.unknown.hashValue){
                purposefulDisconnect = false
                deviceStatusChanged
            }
        }
        
        
    }
    
    func disconnectFromPeriphera(deviceOfInterest: NSUUID)->Bool {
        let deviceToDisconnect = connectedPeripherals[deviceOfInterest]
        if let deviceToDisconnect = deviceToDisconnect {
            activeCentralManager.cancelPeripheralConnection(deviceToDisconnect)
            purposefulDisconnect = true
            return true
        }
        else
        {
            // ERROR: Device does not exist.
            return false
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