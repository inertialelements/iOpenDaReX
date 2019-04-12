
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

class FileLogger {
  private var logFile : String!
  private var logURL: URL?
  private let formatter = DateFormatter()
  
  init(filename:String){
    formatter.dateFormat = "dd-MM-yyyy_HH_mm"
    createLogFile(filename: filename.uppercased())
  }
  
  /// File creation
  private func createLogFile(filename:String){
    
    if filename.count == 0 {
      print("Empty file name")
      return
    }
    
    logFile = filename.uppercased()+"_"+formatter.string(from: Date()) + ".txt"
    
    let fm = FileManager.default
    logURL = fm.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(logFile)
    
    do{
      if fm.fileExists(atPath: logURL!.path){
        try fm.removeItem(at: logURL!)
      }
    }catch{
      print("Cannot removed log file")
    }
    
    var hdrStr = "Timestamp".withCString { String(format: "%25s", $0) } + ", "
    hdrStr += "Step #".withCString { String(format: "%15s", $0) } + ", "
    hdrStr += "X".withCString { String(format: "%15s", $0) } + ", "
    hdrStr += "Y".withCString { String(format: "%15s", $0) } + ", "
    hdrStr += "Z".withCString { String(format: "%15s", $0) } + ", "
    hdrStr += "heading".withCString { String(format: "%15s", $0) } + ", "
    hdrStr += "distance".withCString { String(format: "%15s", $0) }
    writeToLog(hdrStr+"\n")
  }
  
    
  func writeSWDRToLog(_ stepData: StepData){
      var stepStr = stepData.timestamp.toString().withCString { String(format: "%25s", $0) } + ", "
      stepStr += String.init(format: "%15d, %15.2f, %15.2f, %15.2f, %15.2f, %15.2f\n", stepData.stepCount, stepData.x, stepData.y, stepData.z, stepData.heading, stepData.distance)
      writeToLog(stepStr)
  }
    
  func writeToLog(_ string: String) {
    if let handle = try? FileHandle(forWritingTo: logURL!) {
      handle.seekToEndOfFile()
      handle.write(string.data(using: .utf8)!)
      handle.closeFile()
    } else {
      try? string.data(using: .utf8)?.write(to: logURL!)
    }
  }
  
}
