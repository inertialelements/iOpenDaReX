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



class MainViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {
    var manager:CBCentralManager? = nil
    var mainPeripheral:CBPeripheral? = nil
 
    @IBOutlet weak var stopWatchLbl: UILabel!
    @IBOutlet weak var stepCountLbl: UILabel!
    @IBOutlet weak var distanceLbl: UILabel!
    @IBOutlet weak var avgSpeedLbl: UILabel!
    @IBOutlet weak var xLbl: UILabel!
    @IBOutlet weak var yLbl: UILabel!
    @IBOutlet weak var zLbl: UILabel!
    @IBOutlet weak var startBtn: UIButton!
    
    // Variables
    var uartParser : UARTParser? = nil
    var writeCharacteristic:CBCharacteristic? = nil
    var readCharacteristic:CBCharacteristic? = nil
    var isStart : Bool = false
    
    let BLEService = "0003CDD0-0000-1000-8000-00805F9B0131"
    let BLEWriteCharacteristic  = "0003CDD2-0000-1000-8000-00805F9B0131"
    let BLEReadCharacteristic = "0003CDD1-0000-1000-8000-00805F9B0131"
    
    internal let serialQueue = DispatchQueue(label: "serial-queue", qos: .userInteractive)
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.leftBarButtonItem = nil
        
        let leftButton = UIButton()
        leftButton.setBackgroundImage(UIImage(named: "inertial_logo"), for: .normal)
        leftButton.frame = CGRect(origin: CGPoint(x: 0,y :0), size: CGSize(width: 30, height: 30))
        
        let leftBarButton = UIBarButtonItem()
        leftBarButton.customView = leftButton
        self.navigationItem.leftBarButtonItem = leftBarButton
        
        uartParser = UARTParser.sharedInstance
        uartParser?.setViewController(mainViewController: self)
        
        manager = CBCentralManager(delegate: self, queue: nil);
        
        customiseNavigationBar()

    }
    
    func customiseNavigationBar () {
        
        self.navigationItem.rightBarButtonItem = nil
        
        let rightButton = UIButton()
        
        if (mainPeripheral == nil) {
            rightButton.setTitle("Scan", for: [])
            rightButton.setTitleColor(UIColor.white, for: [])
            rightButton.frame = CGRect(origin: CGPoint(x: 0,y :0), size: CGSize(width: 60, height: 30))
            rightButton.addTarget(self, action: #selector(self.scanButtonPressed), for: .touchUpInside)
            self.navigationItem.title = nil
        } else {
            rightButton.setTitle("Disconnect", for: [])
            rightButton.setTitleColor(UIColor.white, for: [])
            rightButton.frame = CGRect(origin: CGPoint(x: 0,y :0), size: CGSize(width: 100, height: 30))
            rightButton.addTarget(self, action: #selector(self.disconnectButtonPressed), for: .touchUpInside)
            self.navigationItem.title = mainPeripheral?.name
        }
        
        let rightBarButton = UIBarButtonItem()
        rightBarButton.customView = rightButton
        self.navigationItem.rightBarButtonItem = rightBarButton
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if (segue.identifier == "scan-segue") {
            let scanController : DeviceSearchViewController = segue.destination as! DeviceSearchViewController
            
            //set the manager's delegate to the scan view so it can call relevant connection methods
            manager?.delegate = scanController
            scanController.manager = manager
            scanController.parentView = self
        }
        
    }
    
    // MARK: Button Methods
    @objc func scanButtonPressed() {
        performSegue(withIdentifier: "scan-segue", sender: nil)
    }
    
    @objc func disconnectButtonPressed() {
        //this will call didDisconnectPeripheral, but if any other apps are using the device it will not immediately disconnect
        manager?.cancelPeripheralConnection(mainPeripheral!)
        mainPeripheral = nil
        self.navigationItem.title = nil
    }
    
    @IBAction func sendButtonPressed(_ sender: AnyObject) {
        
        if !isStart {
            if mainPeripheral == nil {
                print("Device is not connected")
                let alert = UIAlertController(title: "Alert", message: "Device is not connected", preferredStyle: UIAlertController.Style.alert)
                alert.addAction(UIAlertAction(title: "Ok", style: UIAlertAction.Style.default, handler: nil))
                self.present(alert, animated: true, completion: nil)
                return
            }
            let value: [UInt8] = [0x34, 0x00, 0x34]
            print("Send data \(value): \(Date().toString())")
            sendData(bytesData: value)
        }else {
            let stop_pro: [UInt8] = [0x22, 0x00, 0x22]
            let stop_sys: [UInt8] = [0x32, 0x00, 0x32]
            sendData(bytesData: stop_pro)
            usleep(useconds_t(100*1000))
            sendData(bytesData: stop_sys)
        }
        isStart = !isStart
    }
    
    
    func sendData(bytesData : [UInt8]){
        if (mainPeripheral != nil) {
            mainPeripheral?.writeValue(Data(bytes: bytesData), for: writeCharacteristic!, type: CBCharacteristicWriteType.withoutResponse)
        }
    }
    
    // MARK: - CBCentralManagerDelegate Methods
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        mainPeripheral = nil
        customiseNavigationBar()
        print("Disconnected" + peripheral.name!)
        self.startBtn.setTitle("START", for: .normal)
        self.startBtn.backgroundColor = UIColor.green.withAlphaComponent(0.8)
        uartParser?.swdr_flag = false
    }
    
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print(central.state)
    }
    
    // MARK: CBPeripheralDelegate Methods
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
        for service in peripheral.services! {
            
            print("Service found with UUID: " + service.uuid.uuidString)
            if (service.uuid.uuidString == BLEService) {
                peripheral.discoverCharacteristics(nil, for: service)
                
            }
            
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        if (service.uuid.uuidString == BLEService) {
            print("Available Characteristics")
            for characteristic in service.characteristics! {
                print(characteristic)
                if (characteristic.uuid.uuidString == BLEWriteCharacteristic) {
                    //we'll save the reference, we need it to write data
                    writeCharacteristic = characteristic
                    
                    print("Found MIMU Data Write Characteristic")
                }
                if (characteristic.uuid.uuidString == BLEReadCharacteristic) {
                    //we'll save the reference, we need it to read data
                    readCharacteristic = characteristic
                    
                    //Set Notify is useful to read incoming data async
                    peripheral.setNotifyValue(true, for: characteristic)
                    print("Found MIMU Read Characteristic")
                }
            }
            
        }
        
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        if (characteristic.uuid.uuidString == BLEReadCharacteristic) {
            //data recieved
            if(characteristic.value != nil) {
                self.serialQueue.async { [unowned self] in
                    self.uartParser?.parseData(device_name: peripheral.name!, data: characteristic.value!)
                }
            }
        }
    }
    
}

