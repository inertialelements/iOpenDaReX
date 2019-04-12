//
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

import Foundation
import UIKit

class UARTParser {
    
    static var dateFormat = "yyyy-MM-dd hh:mm:ss" //"yyyy-MM-dd hh:mm:ss.SSS"
    static var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = dateFormat
        return formatter
    }
    static let sharedInstance = UARTParser()
    
    var mainViewController :MainViewController? = nil
    
    let  START_ACK : String = "A0 34 00 D4"
    let  STOP_ACK1 : String = "A0 22 00 C2"
    let  STOP_ACK2 : String = "A0 32 00 D2"
    
    var buffer : String = ""
    var swdr_flag : Bool = false
    var package_number_old : Int = -1
    var swdr_data : [Float] = [0.0, 0.0, 0.0, 0.0, 0.0]
    var distance3D : Float = 0.0 // gait length or stride length
    var stepCount : Int = 0
    var startTS : Int = 0
    var lastStepTS : Int = 0
    var speedNow : Float = 0.0
    var avgSpeed : Float = 0.0
    var fileLogger : FileLogger? = nil
    
    private  init(){
       
    }
    
    func setViewController(mainViewController :MainViewController){
        self.mainViewController = mainViewController
    }
    
    func parseData(device_name: String, data : Data)  {
        let hexString = data.convertToHexString(options: .upperCase, spaceNeeded: true)
//        buffer.append(hexString)
        print("Received data: \(hexString)")
        
        if hexString.contains(START_ACK) {
            swdr_flag = true
            reset()
            DispatchQueue.main.async {
                self.mainViewController?.startBtn.setTitle("STOP"
                    , for: .normal)
                self.mainViewController?.startBtn.backgroundColor = UIColor.red.withAlphaComponent(0.8)
            }
            fileLogger = FileLogger(filename: device_name)
        }else if hexString.contains(STOP_ACK1) || hexString.contains(STOP_ACK2){
            swdr_flag = false
            DispatchQueue.main.async {
                self.mainViewController?.startBtn.setTitle("START"
                    , for: .normal)
                self.mainViewController?.startBtn.backgroundColor = UIColor.green.withAlphaComponent(0.8)
            }
        }
        
        if swdr_flag {
            var idx : Int = 0
            var header: [Int] = []
            let byteArray: [UInt8] = data.map { $0 }
            if byteArray.count < 62 {
                return
            }
            for _ in 0..<4 {
                let temp = Int(byteArray[idx] & UInt8(0xFF));          //HEADER ASSIGNED
                idx += 1
//                print( temp)
                header.append(temp)
            }
            
            var payload_data : [Float] = []
            for _ in 0..<4 {
                var item : [UInt8] = []
                for _ in 0..<4 {
                   item.append(byteArray[idx])
                   idx += 1
                }
                payload_data.append(bytesToFloat(bytes: item))
            }
            // idx += 2                                               // FOR SKIPPING CHECKSUM
            let pkg_num1 = header[1]
            let pkg_num2 = header[2]
            let swdr_ack = createAck(pkg_num_1: pkg_num1, pkg_num_2: pkg_num2)
            writeAck(ack: swdr_ack)
            
            let package_number = pkg_num1*256 + pkg_num2;        //PACKAGE NUMBER ASSIGNED
            
            if(package_number_old != package_number)
            {
                stepwise_dr_tu(dX: payload_data)
                let currentTS = Int(Date().timeIntervalSince1970)
                let total_time = Float(currentTS - startTS)
                DispatchQueue.main.async {
                    self.mainViewController?.stopWatchLbl.text = self.convertSectoMinSec(sec: Int(total_time))
                }
                if(distance3D >= 0.05)
                {
                    let timeDiff = Float(currentTS - lastStepTS)
                    
                    lastStepTS = currentTS
                    
                    speedNow = (distance3D*3600)/(timeDiff*1000)

                    avgSpeed = (swdr_data[4]*3600)/(total_time*1000)
                    //let stride_frequency = (1.0 / (timeDiff)); // stride frequency
                    stepCount += 1
                    let  stepData =  StepData(x: swdr_data[0], y: swdr_data[1], z: swdr_data[2], heading: swdr_data[3], distance: swdr_data[4], stepCount: stepCount, timestamp: Date())
//                    print("x=\(stepData.x), y=\(stepData.y), z=\(stepData.z), theta=\(stepData.heading), dis=\(stepData.distance), stepCount=\(stepData.stepCount), timestamp=\(stepData.timestamp.toString()),")
                    DispatchQueue.main.async {
                        self.mainViewController?.stepCountLbl.text = "\(stepData.stepCount)"
                        self.mainViewController?.distanceLbl.text = String(format: "%.1f m", stepData.distance)
                        self.mainViewController?.avgSpeedLbl.text = String(format: "%.2f km/hr", self.avgSpeed)
                        self.mainViewController?.xLbl.text = String(format: "%.2f m", stepData.x)
                        self.mainViewController?.yLbl.text = String(format: "%.2f m", stepData.y)
                        self.mainViewController?.zLbl.text = String(format: "%.2f m", stepData.z)
                    }
                    fileLogger?.writeSWDRToLog(stepData)
                }
                package_number_old = package_number
            }
        }
        
    }
    
    func createAck( pkg_num_1: Int, pkg_num_2: Int)->[UInt8]
    {
        var ack : [UInt8] = []
        ack.append(0x01)
        ack.append(UInt8(pkg_num_1));
        ack.append(UInt8(pkg_num_2));
        ack.append(UInt8((1+pkg_num_1+pkg_num_2-(1+pkg_num_1+pkg_num_2) % 256)/256))
        ack.append(UInt8((1+pkg_num_1+pkg_num_2) % 256))
        return ack;
    }
    
    func writeAck(ack: [UInt8]){
        DispatchQueue.main.async {
            self.mainViewController?.sendData(bytesData: ack)
        }
    }
    
    func stepwise_dr_tu(dX : [Float])
    {
        var delta : [Float] = [0.0, 0.0, 0.0, 0.0]
        let sin_phi = sin(swdr_data[3]);
        let cos_phi = cos(swdr_data[3]);
        //Log.i(TAG, "Sin_phi and cos_phi created");
        delta[0] = cos_phi*dX[0]-sin_phi*dX[1];
        delta[1] = sin_phi*dX[0]+cos_phi*dX[1];
        delta[2] = dX[2];
        swdr_data[0] += delta[0];
        swdr_data[1] += delta[1];
        swdr_data[2] += delta[2];
        swdr_data[3] += dX[3];
        distance3D = sqrt((delta[0]*delta[0]+delta[1]*delta[1]+delta[2]*delta[2]));
        swdr_data[4] += sqrt((delta[0]*delta[0]+delta[1]*delta[1]))
    }
    
    func reset(){
        swdr_data[0] = 0.0
        swdr_data[1] = 0.0
        swdr_data[2] = 0.0
        swdr_data[3] = 0.0
        swdr_data[4] = 0.0
        stepCount = 0
        distance3D = 0.0
        startTS = Int(Date().timeIntervalSince1970)
        lastStepTS = Int(Date().timeIntervalSince1970)
        DispatchQueue.main.async {
            self.mainViewController?.stopWatchLbl.text = "00:00:00"
            self.mainViewController?.stepCountLbl.text = "0"
            self.mainViewController?.distanceLbl.text = "0.0 m"
            self.mainViewController?.avgSpeedLbl.text = "0.00 km/hr"
            self.mainViewController?.xLbl.text = "0.00 m"
            self.mainViewController?.yLbl.text = "0.00 m"
            self.mainViewController?.zLbl.text = "0.00 m"
        }
    }
    
    func bytesToFloat(bytes b: [UInt8]) -> Float {
        let bigEndianValue = b.withUnsafeBufferPointer {
            $0.baseAddress!.withMemoryRebound(to: UInt32.self, capacity: 1) { $0.pointee }
        }
        let bitPattern = UInt32(bigEndian: bigEndianValue)
        
        return Float(bitPattern: bitPattern)
    }
    
    func convertSectoMinSec(sec: Int)-> String{
        let hr = sec/3600
        let min = (sec%3600)/60
        let sec = sec%60
        return String(format: "%02d:%02d:%02d", hr, min, sec)
    }
    
    
}
