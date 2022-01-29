//
//  main.swift
//  GoldByte
//
//  Created by Wiktor Wójcik on 24/11/2021.
//

#if canImport(Cocoa)
import Cocoa
#endif
import Foundation
import GoldByte

enum Option {
	case DebugMode
}

var fileIndex = 1

var options: Option? = nil

if CommandLine.arguments.count <= 1 {
	let shell = GBShell()
	shell.start()
} else {
	if CommandLine.arguments[1] == "-info" {
		print(GBCore.shared.getInfo())
		exit(0)
	}
	
	var path = ""
	
	if CommandLine.arguments[fileIndex].hasPrefix("~") {
		path = (CommandLine.arguments[fileIndex] as NSString).expandingTildeInPath
	} else {
		let toolsDirectory = URL(string: CommandLine.arguments[0])!.deletingLastPathComponent().absoluteString
		print("relative path: \(toolsDirectory + CommandLine.arguments[fileIndex])")
		
		if FileManager.default.fileExists(atPath: CommandLine.arguments[fileIndex]) {
			path = CommandLine.arguments[fileIndex]
		} else if FileManager.default.fileExists(atPath: toolsDirectory + CommandLine.arguments[fileIndex]) {
			path = toolsDirectory + CommandLine.arguments[fileIndex]
		}
	}
	
	if !path.hasSuffix(".goldbyte") {
		path.append(".goldbyte")
	}
	
	if !FileManager.default.fileExists(atPath: path) {
		print("ERROR: No file found at: \(path)")
		exit(1)
	}
	
	do {
		let code = try String(contentsOfFile: path)
		
		GBCore.shared.applyPlatformSpecific()

		if options == .DebugMode {
			GBCore.shared.debug(code: code, filePath: path)
		} else {
			GBCore.shared.start(withCode: code, filePath: path)
		}
	} catch {
		print("ERROR: \(error.localizedDescription)")
	}
}
