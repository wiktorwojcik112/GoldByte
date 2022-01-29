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
	
	var pathToFile = (CommandLine.arguments[fileIndex] as NSString).expandingTildeInPath
	
	if !pathToFile.hasSuffix(".goldbyte") {
		pathToFile.append(".goldbyte")
	}
	
	if !FileManager.default.fileExists(atPath: pathToFile) {
		print("ERROR: No file found at: \(pathToFile)")
		exit(1)
	}
	
	do {
		let code = try String(contentsOfFile: pathToFile)
		
		GBCore.shared.applyPlatformSpecific()

		if options == .DebugMode {
			GBCore.shared.debug(code: code, filePath: pathToFile)
		} else {
			GBCore.shared.start(withCode: code, filePath: pathToFile)
		}
	} catch {
		print("ERROR: \(error.localizedDescription)")
	}
}
