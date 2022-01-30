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
import XCTest

enum Option {
	case DebugMode
}

var options: Option? = nil

if CommandLine.arguments.count <= 1 {
	let shell = GBShell()
	shell.start()
} else {
	if CommandLine.arguments[1] == "link" {
		let process = Process()
		
		var lnPath = ""
		
		#if os(OSX)
			lnPath = "/bin/ln"
		#elseif os(Linux)
			lnPath = "/usr/bin/ln"
		#else
			print("Error: Unsupported OS.")
			exit(1)
		#endif
		
		if #available(macOS 10.13, *) {
			process.executableURL = URL(fileURLWithPath: lnPath)
		} else {
			process.launchPath = lnPath
		}
		
		process.arguments = ["-s", CommandLine.arguments[0], "/usr/local/bin"]
		
		do {
			if #available(macOS 10.13, *) {
				try process.run()
			} else {
				process.launch()
			}
		} catch {
			print("ERROR: Can't link: \(error.localizedDescription)")
			exit(1)
		}
		
		process.waitUntilExit()
		
		if process.terminationStatus == 0 {
			print("Linked gbtool to /usr/local/bin succesfully. You can now use gbtool from your shell.")
		} else {
			print("Linking gbtool to /usr/local/bin failed. Please, file a issue on GitHub with details of your operating system.")
		}
		
		exit(0)
	}
	
	if CommandLine.arguments[1] == "info" {
		print(GBCore.shared.getInfo())
		exit(0)
	}
	
	var path = ""
	
	let providedFilePath = CommandLine.arguments[1]
	
	if !providedFilePath.hasSuffix(".goldbyte") {
		print("ERROR: File must have .goldbyte extension.")
		exit(1)
	}
	
	if providedFilePath.hasPrefix("~") {
		path = (providedFilePath as NSString).expandingTildeInPath
	} else {
		var toolsDirectory = URL(string: CommandLine.arguments[0])!.deletingLastPathComponent().absoluteString
		toolsDirectory.removeLast()
		
		if FileManager.default.fileExists(atPath: providedFilePath) {
			path = providedFilePath
		} else if FileManager.default.fileExists(atPath: toolsDirectory + providedFilePath) {
			path = toolsDirectory + providedFilePath
		} else {
			print("ERROR: No file found.")
			exit(1)
		}
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
