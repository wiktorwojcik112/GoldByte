//
//  GBShell.swift
//  GoldByte
//
//  Created by Wiktor Wójcik on 30/11/2021.
//

import Foundation
#if canImport(AppKit)
import AppKit
#endif

class GBShell {
	typealias GBMacroAction = GBStorage.GBMacroAction
	
	let fileManager = FileManager.default
	var core: GBCore
	
	var currentPath: URL {
		URL(string: core.storage["PATH"].value)!
	}
	
	var pathDirectories: [String] = [
		"/usr/bin/",
		"~/usr/local/bin/"
	]
	
	init() {
		core = GBCore(configuration: GBCore.defaultConfiguration, macros: nil)
		core.addMacros(getMacros(withStorage: core.storage))
		core.storage["PATH"] = .init(value: ("~" as NSString).expandingTildeInPath as String, type: .url, scope: .global, isConstant: false)
		core.configuration.flags = []
		core.configuration.console = ShellConsole()
	}
	
	func start() {
		print("GoldByte \(core.version) by Wiktor Wójcik\nType :exit to exit.")
		while true {
			print("\(currentPath.lastPathComponent) >> ", terminator: "")
			let line = readLine()! + "\n"
			
			if line.trimmingCharacters(in: .whitespacesAndNewlines) == ":exit" {
				exit(0)
			}
			
			core.start(withCode: line, filePath: "")
		}
	}
	
	func checkPathDirectories(_ path: String) -> String? {
		for pathDirectory in pathDirectories {
			let expanded = ((pathDirectory as NSString).expandingTildeInPath as String)
			
			let newURL = expanded + (expanded.hasSuffix("/") ? "" : "/") + path
			
			var isDirectory: ObjCBool = false
			let fileExists = FileManager.default.fileExists(atPath: newURL, isDirectory: &isDirectory)
			
			if !isDirectory.boolValue && fileExists {
				return pathDirectory
			}
		}
		
		return nil
	}
}

extension GBShell {
	func getMacros(withStorage storage: GBStorage) -> [String: GBMacroAction] {
		GBStorage.buildMacros {
			GBMacro("EXEC") { arguments, line in
				if arguments.count == 0 {
					return .init(type: .macro, description: "Expected at least 1 argument argument, got \(arguments.count).", line: line, word: 0)
				} else if arguments[safely: 0]?.type != "URL" && arguments[safely: 0]?.type != "STRING" {
					return .init(type: .macro, description: "Expected URL, STRING or PLAIN TEXT, got \(arguments[safely: 0]?.type ?? "none").", line: line, word: 0)
				}
				
				var path = storage["PATH"].value
				
				var url = URL(string: "/Users")!
				
				var processArguments = arguments.dropFirst().map { $0.getValue() }
				
				for argument in arguments.dropFirst() {
					processArguments.append(argument.getValue())
				}
				
				if let argument = arguments[0].getValue(forType: URL.self) {
					if argument.pathComponents[0] == "." {
						if argument.pathComponents.count <= 1 {
							url = URL(string: path)!
						} else {
							var absoluteString = argument.absoluteString
							
							absoluteString.remove(at: absoluteString.startIndex)
							
							absoluteString = path + (path.hasSuffix("/") ? "" : "/") + absoluteString
							absoluteString = absoluteString.replacingOccurrences(of: "//", with: "/")
							
							url = URL(string: absoluteString)!
						}
					} else if argument.pathComponents[0] == "~" {
						url = URL(string: (argument.absoluteString as NSString).expandingTildeInPath)!
					} else if argument.pathComponents[0] == ".." {
						path = path.components(separatedBy: "/").dropFirst().dropLast().joined(separator: "/")
						
						var absoluteString = url.absoluteString
						
						absoluteString.remove(at: absoluteString.startIndex)
						absoluteString.remove(at: absoluteString.startIndex)
						
						absoluteString = (path.hasPrefix("/") ? "" : "/") + path + (path.hasSuffix("/") ? "" : "/") + absoluteString
						absoluteString = absoluteString.replacingOccurrences(of: "//", with: "/")
						
						url = URL(string: absoluteString)!
					}
					
					var isDirectory: ObjCBool = false
					let fileExists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
					
					if isDirectory.boolValue || !fileExists {
						return .init(type: .macro, description: "Path \(url.absoluteString) doesn't exist.")
					}
				} else if let argument = arguments[0].getValue(forType: String.self) {
					if let pathDirectory = self.checkPathDirectories(argument) {
						url = URL(fileURLWithPath: pathDirectory + argument)
					} else {
						return .init(type: .macro, description: "Can't find \(argument) in path directories.")
					}
				}
				
				if url.pathExtension == "goldbyte" {
					let code = String(data: FileManager.default.contents(atPath: url.path)!, encoding: .utf8)!
					GBCore.shared.start(withCode: code, filePath: url.path)
					return nil
				}
				
				let process = Process()
				
				if #available(OSX 10.13, *) {
					process.executableURL = URL(fileURLWithPath: url.absoluteString)
				} else {
					process.launchPath = url.absoluteString
				}
				
				let errPipe = Pipe()
				
				process.standardError = errPipe
				
				process.arguments = processArguments
				
				var output: GBError? = nil
				
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
				
				return output
			}
			
			GBMacro("CD") { arguments, line in
				if arguments.count != 1 {
					return .init(type: .macro, description: "Expected 1 argument, got \(arguments.count).", line: line, word: 0)
				} else if arguments[safely: 0]?.type != "URL" {
					return .init(type: .macro, description: "Expected URL, got \(arguments[safely: 0]?.type ?? "none").", line: line, word: 0)
				}
				
				var path = storage["PATH"].value
				
				var url = arguments[0].getValue(forType: URL.self)!
				
				if url.pathComponents[0] == "." {
					if url.pathComponents.count <= 1 {
						url = URL(string: path)!
					} else {
						var absoluteString = url.absoluteString
						
						absoluteString.remove(at: absoluteString.startIndex)
						
						absoluteString = path + (path.hasSuffix("/") ? "" : "/") + absoluteString
						absoluteString = absoluteString.replacingOccurrences(of: "//", with: "/")
						
						url = URL(string: absoluteString)!
					}
				} else if url.pathComponents[0] == "~" {
					url = URL(string: (url.absoluteString as NSString).expandingTildeInPath)!
				} else if url.pathComponents[0] == ".." {
					path = path.components(separatedBy: "/").dropFirst().dropLast().joined(separator: "/")
					
					var absoluteString = url.absoluteString
					
					absoluteString.remove(at: absoluteString.startIndex)
					absoluteString.remove(at: absoluteString.startIndex)
					
					absoluteString = (path.hasPrefix("/") ? "" : "/") + path + (path.hasSuffix("/") ? "" : "/") + absoluteString
					absoluteString = absoluteString.replacingOccurrences(of: "//", with: "/")
					
					url = URL(string: absoluteString)!
				}
				
				if !FileManager.default.fileExists(atPath: url.path) {
					return .init(type: .macro, description: "Path \(url.absoluteString) doesn't exist.")
				}
				
				storage["PATH"] = .init(value: url.absoluteString, type: .url, scope: .global, isConstant: false)
				
				return nil
			}
			
			GBMacro("LS") { arguments, line in
				if arguments.count != 0 {
					return .init(type: .macro, description: "LS expects no arguments.", line: line, word: 0)
				}
				
				let path = storage["PATH"].value
				
				do {
					let files = try self.fileManager.contentsOfDirectory(atPath: path)
					
					var width = 0
					
					for file in files {
						if width < file.count {
							width = file.count
						}
					}
					
					width += 3
					
					for (n, file) in files.enumerated() {
						let n = n + 1
						
						//print(file, withWidth: width)
						print(file + "   ", terminator: "")
						
						if n % 5 == 0 {
							print("\n")
						}
					}
				} catch {
					return .init(type: .macro, description: error.localizedDescription, line: line, word: 0)
				}
				
				print("\n")
				
				return nil
			}
		}
	}
}

func print(_ text: String, withWidth width: Int) {
	var indentation = ""
	
	if width > text.count {
		for _ in 0...(width - text.count) {
			indentation += " "
		}
	}
	
	print(indentation + text, terminator: "")
}

class ShellConsole: GBConsole {
	func warning(_ string: String) {
		text("[WARNING] \(string)")
	}
	
	func text(_ string: String) {
		print(string)
	}
	
	func input() -> String {
		readLine()!
	}
}
