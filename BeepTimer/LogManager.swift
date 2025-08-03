//
//  LogManager.swift
//  BeepTimer
//
//  Created by 임재혁 on 8/3/25.
//

import SwiftUI

public enum LogLevel: Int, CustomStringConvertible{
    case debug = 1
    case info = 2
    case error = 3
    
    public var description: String{
        switch self{
        case .debug: return "- DEBUG"
        case .info: return "- INFO"
        case .error: return "- ERROR"
        }
    }
}

public class logger {
    static var logLevel: LogLevel = .debug
    
    public static func d(_ message:String, file: String = #file, line: Int = #line, function: String = #function){
        log(message, level: .debug, file: file, line: line, function: function)
    }
    
    public static func i(_ message:String, file: String = #file, line: Int = #line, function: String = #function){
        log(message, level: .info, file: file, line: line, function: function)
    }
    
    public static func e(_ message:String, file: String = #file, line: Int = #line, function: String = #function){
        log(message, level: .error, file: file, line: line, function: function)
    }
    
    private static func log(_ message: String, level: LogLevel, file: String, line: Int, function: String){
        if level.rawValue >= logLevel.rawValue{
            let fileName = URL(fileURLWithPath: file).lastPathComponent
            print("BeepTimer: \(level.description) \(fileName):\(line) \(function) - \(message)")
        }
    }
}
