//
//  TableViewController.swift
//  HM10Terminal2
//
//  Created by Casey Brittain on 9/1/15.
//  Copyright © 2015 Honeysuckle Hardware. All rights reserved.
//

import UIKit
import CoreBluetooth


class TableViewController: UITableViewController, CBPeripheralDelegate, bleSerialDelegate {
    
    var discoveredDevicesNSUUIDSortedByRSSI: Array<NSUUID> = []

    var refreshController = UIRefreshControl()
    
    func searchTimerExpired(controller: AnyObject) {
        
    }
    
    func deviceStatusChanged(controller: AnyObject){
        
    }

    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
    }
    
    override func viewDidAppear(animated: Bool) {
        hm10serialManager.delegate = self
        
        // Setup pull-down-on-scroll-to-refresh controller
        refreshController.addTarget(self, action: Selector("refreshTableOnPullDown"), forControlEvents: UIControlEvents.ValueChanged)
        self.refreshControl = refreshController
        
        // Setup hm10serialManager behavior.
        hm10serialManager.setAutomaticReconnectOnDisconnect(true, tries: 3, timeBetweenTries: 0.5)
        hm10serialManager.setMutipleConnections(10)
        hm10serialManager.setRetryConnectAfterFail(true, tries: 3, timeBetweenTries: 0.5)
        
        // Begin search automatically.
        hm10serialManager.search(self, nameOfCallback: "callBack", timeoutSecs: 1.0)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        //print("Number of discovered devices: \(hm10serialManager.getNumberOfDiscoveredDevices())")
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return discoveredDevicesNSUUIDSortedByRSSI.count
    }


    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("cell", forIndexPath: indexPath) as! devicesCell

        // Configure the cell if there are any discovered devices.
        if(!discoveredDevicesNSUUIDSortedByRSSI.isEmpty){

            var currentStatusString: String = ""
            
            if(hm10serialManager.alreadyConnected(discoveredDevicesNSUUIDSortedByRSSI[indexPath.row])){
                currentStatusString = " -- Connected"
            }
            
            // Create a custom cell.
            cell.nameLabel.text = hm10serialManager.getDeviceName(discoveredDevicesNSUUIDSortedByRSSI[indexPath.row]) + currentStatusString

            // Get discovered device's RSSI.
            let rssi = hm10serialManager.getDeviceRSSI(discoveredDevicesNSUUIDSortedByRSSI[indexPath.row])
            cell.detailTextLabel?.text = String(rssi)

            // Map RSSI to color scheme.
            let red = mapNumber(rssi, inMin: -20, inMax: -127, outMin: 0, outMax: 1.0)
            let green = mapNumber(rssi, inMin: -20, inMax: -127, outMin: 1.0, outMax: 0)
            
            // Setup RSSI graphic.
            let layer = CALayer()
            cell.deviceView.layer.sublayers = nil
            layer.frame = cell.deviceView.bounds
            layer.contentsGravity = kCAGravityCenter
            layer.magnificationFilter = kCAFilterLinear
            layer.geometryFlipped = false
            layer.backgroundColor = UIColor(red: CGFloat(red), green: CGFloat(green), blue: 0.0, alpha: 1.0).CGColor
            layer.opacity = 1.0
            layer.hidden = false
            layer.masksToBounds = false
            layer.cornerRadius = cell.deviceView.bounds.width / 2
            layer.borderWidth = 1.0
            layer.borderColor = UIColor.blackColor().CGColor
            layer.shadowOpacity = 0.75
            layer.shadowOffset = CGSize(width: 0, height: 3)
            layer.shadowRadius = 3.0
            
            // Add RSSI graphic.
            cell.deviceView.layer.addSublayer(layer)
        }
        return cell
    }

    override func tableView(tableView: UITableView, didHighlightRowAtIndexPath indexPath: NSIndexPath) {
        
        // Connect to the selected device.
        hm10serialManager.connectToDevice(discoveredDevicesNSUUIDSortedByRSSI[indexPath.row])
        if let navigationController = navigationController {
            //navigationController.popToRootViewControllerAnimated(true)
        }
    }
    
    func callBack(){
        
        // Invalidate timers and such.
        hm10serialManager.searchTimerTimeout()
        discoveredDevicesNSUUIDSortedByRSSI = hm10serialManager.getSortedArraysBasedOnRSSI().nsuuids
        
        // Reload the data, then end the refreshing controller
        self.tableView.reloadData()
        refreshController.endRefreshing()
    }

    func refreshTableOnPullDown() {

        // Refresh device list.
        hm10serialManager.search(self, nameOfCallback: "callBack", timeoutSecs: 1.0)
    }
    
    func mapNumber(x: Int, inMin: Double, inMax: Double, outMin: Double, outMax: Double) -> Double {
        let y = Double(x)
        return ((y - inMin) * (outMax - outMin)) / (inMax - inMin) + outMin
    }

    /*
    // Override to support conditional editing of the table view.
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            // Delete the row from the data source
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
        } else if editingStyle == .Insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(tableView: UITableView, moveRowAtIndexPath fromIndexPath: NSIndexPath, toIndexPath: NSIndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}

class devicesCell: UITableViewCell {
    

    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var deviceView: UIView!

    override func awakeFromNib() {
        super.awakeFromNib()
        
    }
    
    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
}
