//
//  ViewController.swift
//  HM10Terminal2
//
//  Created by Casey Brittain on 8/22/15.
//  Copyright © 2015 Honeysuckle Hardware. All rights reserved.
//

import UIKit
import CoreLocation

let hm10serialManager = bleSerialManager()

class ViewController: UIViewController, bleSerialDelegate, CLLocationManagerDelegate {
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        // Do any additional setup after loading the view, typically from a nib.
        
    }
    
    override func viewWillAppear(animated: Bool) {
        hm10serialManager.delegate = self
        

    }

    override func viewDidAppear(animated: Bool) {

    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

