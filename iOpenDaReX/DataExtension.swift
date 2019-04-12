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

extension Data {
    struct HexEncodingOptions: OptionSet {
        let rawValue: Int
        static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
    }
    
    func convertToHexString(options: HexEncodingOptions = [], spaceNeeded: Bool = false) -> String {
        let hexDigits = Array((options.contains(.upperCase) ? "0123456789ABCDEF" : "0123456789abcdef").utf16)
        var chars: [unichar] = []
        if spaceNeeded {
            chars.reserveCapacity(3 * count)
        }else{
            chars.reserveCapacity(2 * count)
        }
        
        for byte in self {
            chars.append(hexDigits[Int(byte / 16)])
            chars.append(hexDigits[Int(byte % 16)])
            if spaceNeeded {
                chars.append(0x20)
            }
        }
        return String(utf16CodeUnits: chars, count: chars.count)
    }
}

extension Date {
    func toString() -> String {
        return UARTParser.dateFormatter.string(from: self as Date)
    }
}

