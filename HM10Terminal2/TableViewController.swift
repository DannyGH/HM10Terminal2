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
    
    var deviceListArray = []
    
    func searchTimerExpired(controller: AnyObject) {
        print("BOOYAH!")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
        hm10serialManager.delegate = self
        print(hm10serialManager.getDeviceState())
        hm10serialManager.search(self, nameOfCallback: "callBack", timeoutSecs: 1)
        deviceListArray = hm10serialManager.getDeviceListAsArray()

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return hm10serialManager.getNumberOfDiscoveredDevices()
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return 1
    }


    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("cell", forIndexPath: indexPath)

        let deviceList = hm10serialManager.getDeviceListAsArray()
        let deviceOfInterest = deviceList[indexPath.row]
        print(deviceOfInterest)
        
        cell.textLabel?.text = hm10serialManager.getDeviceName(deviceOfInterest)
        cell.detailTextLabel?.text = String(hm10serialManager.getDeviceRSSI(deviceOfInterest))

        // Configure the cell...

        return cell
    }

    func callBack(){
        hm10serialManager.searchTimerTimeout()
        self.tableView.reloadData()
        print("YAY!")
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
