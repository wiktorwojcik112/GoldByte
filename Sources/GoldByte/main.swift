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

enum Option {
	case DebugMode
}

var fileIndex = 1

var options: Option? = nil

if CommandLine.arguments.count == 1 {
	let shell = GBShell()
	shell.start()
} else {
	if CommandLine.arguments[1] == "-d" {
		options = .DebugMode
		fileIndex += 1
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
		
		GBCore.shared.addMacros(GBCore.shared.getMacSpecificMacros(withStorage: GBCore.shared.storage))
		
		if options == .DebugMode {
			GBCore.shared.debug(code: code, filePath: pathToFile)
		} else {
			GBCore.shared.start(withCode: code, filePath: pathToFile)
		}
	} catch {
		print("ERROR: \(error.localizedDescription)")
	}
}

extension GBCore {
	func getMacSpecificMacros(withStorage storage: GBStorage) -> [String: GBMacroAction] {
		return GBStorage.buildMacros {
			GBMacro("SHELL") { arguments, line in
				if arguments.count == 1 {
					if case .string(let script) = arguments[0] {
						var output: GBError? = nil
						
#if canImport(Cocoa)
						let process = Process()
						
						if #available(OSX 10.13, *) {
							process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
						} else {
							process.launchPath = "/usr/bin/env"
						}
						
						let errPipe = Pipe()
						
						process.standardError = errPipe
						
						let script = script.trimmingCharacters(in: .whitespacesAndNewlines)
						
						var arguments = script.prepare(withStorage: storage).components(separatedBy: " ")
						
						process.arguments = arguments
						
						if #available(OSX 10.13, *) {
							do {
								try process.run()
							} catch {
								output = .init(type: .macro, description: "Problem while starting script: \(error.localizedDescription)", line: line, word: 0)
							}
						}
						
						process.terminationHandler = { _ in
							if process.terminationStatus != 0 {
								if let error = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) {
									output = .init(type: .macro, description: "Shell error: \(error)", line: line, word: 0)
								}
							}
							
							process.terminationHandler = nil
						}
						
						if process.isRunning {
							process.waitUntilExit()
						}
#else
						output = .init(type: .macro, description: "Can't import Cococa library while it is required.", line: line, word: 0)
#endif
						
						return output
					} else {
						return .init(type: .macro, description: "Expected STRING, got \"\(arguments[0].type)\".", line: line, word: 0)
					}
				} else {
					return .init(type: .macro, description: "Expected 1 argument, but got \(arguments.count) arguments.", line: line, word: 0)
				}
				
				return nil
			}
		}
	}
}
