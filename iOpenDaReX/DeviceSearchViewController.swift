/*
 * * Copyright (C) 2019 GT Silicon Pvt Ltd
 *
 * Licensed under the Creative Commons Attribution 4.0
 * International Public License (the "CCBY4.0 License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * https://creativecommons.org/licenses/by/4.0/legalcode
 *
 *
 * */

import UIKit
import CoreBluetooth

class DeviceSearchViewController: UITableViewController, CBCentralManagerDelegate {
    
    var peripherals:[CBPeripheral] = []
    var deviceToRSSI:[String: NSNumber] = [:]
    var manager:CBCentralManager? = nil
    var parentView:MainViewController? = nil
    let rightButton = UIButton()
    @IBOutlet var deviceListTableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.rightBarButtonItem = nil

        rightButton.setTitle("Refresh", for: [])
        rightButton.setTitleColor(UIColor.white, for: [])
        rightButton.frame = CGRect(origin: CGPoint(x: 0,y :0), size: CGSize(width: 60, height: 30))
        rightButton.addTarget(self, action: #selector(self.scanBLEDevices), for: .touchUpInside)

        let rightBarButton = UIBarButtonItem()
        rightBarButton.customView = rightButton
        self.navigationItem.rightBarButtonItem = rightBarButton

        deviceListTableView.register(UINib(nibName: "DeviceTableViewCell", bundle: nil), forCellReuseIdentifier: "device_cell")
        deviceToRSSI = [:]
    }
    
    override func viewDidAppear(_ animated: Bool) {
        scanBLEDevices()
    }    
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return peripherals.count
    }
    
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "device_cell", for: indexPath)  as! DeviceTableViewCell
        let peripheral = peripherals[indexPath.row]
        cell.deviceNameLbl.text = peripheral.name
        cell.rssiLbl.text = "\(String(describing: deviceToRSSI[peripheral.name!]!))"
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let peripheral = peripherals[indexPath.row]
        
        manager?.connect(peripheral, options: nil)
    }
    
    // MARK: BLE Scanning
    @objc func scanBLEDevices() {
        //manager?.scanForPeripherals(withServices: [CBUUID.init(string: parentView!.BLEService)], options: nil)
        
        //if you pass nil in the first parameter, then scanForPeriperals will look for any devices.
        manager?.scanForPeripherals(withServices: nil, options: nil)
        
        //stop scanning after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.stopScanForBLEDevices()
        }
    }
    
    func stopScanForBLEDevices() {
        manager?.stopScan()
    }
    
    // MARK: - CBCentralManagerDelegate Methods
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if(!peripherals.contains(peripheral) && peripheral.name != nil) {
            deviceToRSSI[peripheral.name!] = RSSI
            peripherals.append(peripheral)
        }
        
        self.tableView.reloadData()
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print(central.state)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        
        //pass reference to connected peripheral to parent view
        parentView?.mainPeripheral = peripheral
        peripheral.delegate = parentView
        peripheral.discoverServices(nil)
        
        
        //set the manager's delegate view to parent so it can call relevant disconnect methods
        manager?.delegate = parentView
        parentView?.customiseNavigationBar()
        
        if let navController = self.navigationController {
            navController.popViewController(animated: true)
        }
        
        print("Connected to " +  peripheral.name!)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print(error!)
    }
    
}
