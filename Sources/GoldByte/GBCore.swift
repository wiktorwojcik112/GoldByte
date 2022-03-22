//
//  GBCore.swift
//  GoldByte
//
//  Created by Wiktor Wójcik on 24/11/2021.
//

import Foundation
#if canImport(AppKit)
import AppKit
#endif

protocol GBConsole {
	func text(_ string: String)
	func input() -> String
	func warning(_ string: String)
}

/// GoldByte's core
public class GBCore {
	public typealias GBMacroAction = ([GBValue], Int, String) -> GBError?
	
	public let version = "1.0.1"
	
	public func getInfo() -> String {
		"""
		GoldByte \(version)
		Creator: Wiktor Wójcik
		"""
	}
	
	public static let shared = GBCore(configuration: defaultConfiguration)
	
	public var configuration: Configuration
	
	public static var defaultConfiguration = Configuration(console: DefaultConsole(), errorHandler: DefaultErrorHandler(), debugMode: false, flags: [.allowMultiline, .showExitMessage])
	
	var console: GBConsole {
		configuration.console
	}
	
	var errorHandler: GBErrorHandler {
		configuration.errorHandler
	}
	
	var filePath: String = ""
	
	var macros: [String: GBMacroAction] = [:]
	
	var parser: GBParser
	var interpreter: GBInterpreter
	var storage: GBStorage
	
	enum Flag {
		case allowLibraries
		case allowMultiline
		case showExitMessage
		case noMain
	}
	
	public struct Configuration {
		var console: GBConsole
		var errorHandler: GBErrorHandler
		var debugMode: Bool
		var flags: [Flag]
	}
	
	public func addMacros(_ macros: [String: GBMacroAction]) {
		self.macros.merge(with: macros)
		self.storage.macros = self.macros
	}
	
	public init(configuration: Configuration, macros: [String: GBMacroAction]? = nil) {
		self.configuration = configuration
		
		self.storage = GBStorage(errorHandler: configuration.errorHandler, macros: [String: GBMacroAction]())
		self.parser = GBParser(nil, errorHandler: configuration.errorHandler, storage: storage)
		self.interpreter = GBInterpreter(nil, storage: storage, console: configuration.console, errorHandler: configuration.errorHandler)
		
		if let macros = macros {
			self.macros = macros
		} else {
			self.macros = [:]
			self.macros = getMacros(withStorage: storage)
		}
		
		self.storage.macros = self.macros
		
		self.parser = GBParser(self, errorHandler: configuration.errorHandler, storage: storage)
		self.interpreter = GBInterpreter(self, storage: storage, console: configuration.console, errorHandler: configuration.errorHandler)
	}
	
	func load(with code: String, filePath: String) -> GBError? {
		self.filePath = filePath
		
		let parsingResult: (parsed: [[GBToken]]?, error: GBError?) = parser.parse(code)

		if let error = parsingResult.error {
			return error
		}
		
		let (_, _, error) = interpreter.interpret(parsingResult.parsed!)
		
		if let error = error {
			var error = error
			
			error.description = "[\(filePath)] \(error.description)"
			
			return error
		} else {
			return nil
		}
	}
	
	public func debug(code: String, filePath: String) {
		let debugger = GBDebugger(storage: storage)
		debugger.debug(code: code, filePath: filePath)
	}
	
	public func start(withCode code: String, filePath: String) {
		self.filePath = filePath
		
		let parsingResult: (parsed: [[GBToken]]?, error: GBError?) = parser.parse(code)
		
		if let error = parsingResult.error {
			errorHandler.handle(error)
			console.text("Program exited with exit code: 1\n")
			return
		}
		
		let (_, _, initialError) = interpreter.interpret(parsingResult.parsed!)
		
		if let error = initialError {
			errorHandler.handle(error)
			
			if configuration.flags.contains(.showExitMessage) {
				print("\nProgram exited with exit code: 1\n")
			}
			
			return
		}
		
		if !configuration.flags.contains(.noMain) {
			let (code, _, functionError) = storage.getFunction("main", arguments: [], line: 0)
			
			if let functionError = functionError {
				errorHandler.handle(functionError)
				
				if configuration.flags.contains(.showExitMessage) {
					print("\nProgram exited with exit code: 1\n")
				}
				
				return
			}
			
			let (_, exitCode, error) = interpreter.interpret(code!, isInsideCodeBlock: true, returnType: .number)
			
			if let error = error {
				errorHandler.handle(error)
				
				if configuration.flags.contains(.showExitMessage) {
					print("\nProgram ended with exit code: \(exitCode)\n")
				}
				
				return
			}
		}
		
		if configuration.flags.contains(.showExitMessage) {
			print("\nProgram exited with exit code: 0\n")
		}
	}
	
	public func applyPlatformSpecific() {
		#if os(OSX)
			addMacros(getMacSpecificMacros(withStorage: storage))
		#endif
	}
	
	func getMacSpecificMacros(withStorage storage: GBStorage) -> [String: GBMacroAction] {
		return GBStorage.buildMacros {
			GBMacro("SHELL") { arguments, line, _ in
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
						
						let arguments = script.prepare(withStorage: storage, inNamespace: "").components(separatedBy: " ")
						
						process.arguments = arguments
						
						if #available(OSX 10.13, *) {
							do {
								try process.run()
							} catch {
								output = .init(type: .panic, description: "Problem while starting script: \(error.localizedDescription)", line: line, word: 0)
							}
						}
						
						process.terminationHandler = { _ in
							if process.terminationStatus != 0 {
								if let error = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) {
									output = .init(type: .panic, description: "Shell error: \(error)", line: line, word: 0)
								}
							}
							
							process.terminationHandler = nil
						}
						
						if process.isRunning {
							process.waitUntilExit()
						}
#else
						output = .init(type: .panic, description: "Can't import Cococa library while it is required.", line: line, word: 0)
#endif
						
						return output
					} else {
						return .init(type: .panic, description: "Expected STRING, got \"\(arguments[0].type)\".", line: line, word: 0)
					}
				} else {
					return .init(type: .panic, description: "Expected 1 argument, but got \(arguments.count) arguments.", line: line, word: 0)
				}
			}
		}
	}
}

extension Array {
	subscript(safely index: Int) -> Element? {
		if 0 <= index && index < endIndex {
			return self[index]
		} else {
			return nil
		}
	}
}

extension Dictionary {
	func merged(with mergingDictionary: Dictionary<Key, Value>) -> Dictionary<Key, Value> {
		var thisDictionary = self
		
		for (key, value) in mergingDictionary {
			thisDictionary[key] = value
		}
		
		return thisDictionary
	}
	
	mutating func merge(with mergingDictionary: Dictionary<Key, Value>) {
		for (key, value) in mergingDictionary {
			self[key] = value
		}
	}
}
