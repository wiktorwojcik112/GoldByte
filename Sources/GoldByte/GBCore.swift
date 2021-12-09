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
class GBCore {
	typealias GBMacroAction = GBStorage.GBMacroAction
	
	static let shared = GBCore(configuration: defaultConfiguration)
	
	var configuration: Configuration
	
	static var defaultConfiguration = Configuration(console: DefaultConsole(), errorHandler: DefaultErrorHandler(), debugMode: false, flags: [.allowMultiline, .showExitMessage])
	
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
	}
	
	struct Configuration {
		var console: GBConsole
		var errorHandler: GBErrorHandler
		var debugMode: Bool
		var flags: [Flag]
	}
	
	func addMacros(_ macros: [String: GBMacroAction]) {
		self.macros.merge(with: macros)
		self.storage.macros = self.macros
	}
	
	init(configuration: Configuration, macros: [String: GBMacroAction]? = nil) {
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
		
		if configuration.debugMode {
			print(DebugTools.formatParsingResult(parsingResult.parsed!))
		}
		
		let (_, _, error) = interpreter.interpret(parsingResult.parsed!)
		
		return error
	}
	
	func debug(code: String, filePath: String) {
		let debugger = GBDebugger(storage: storage)
		debugger.debug(code: code, filePath: filePath)
	}
	
	func start(withCode code: String, filePath: String) {
		self.filePath = filePath
		
		let parsingResult: (parsed: [[GBToken]]?, error: GBError?) = parser.parse(code)
		
		if let error = parsingResult.error {
			errorHandler.handle(error)
			console.text("Program exited with exit code: 1")
			return
		}
		
		if configuration.debugMode {
			print(DebugTools.formatParsingResult(parsingResult.parsed!))
		}
		
		let (_, _, error) = interpreter.interpret(parsingResult.parsed!)
		
		if let error = error {
			errorHandler.handle(error)
			
			if configuration.flags.contains(.showExitMessage) {
				print("Program exited with exit code: 1")
			}
			
			return
		}
		
		if configuration.flags.contains(.showExitMessage) {
			print("Program exited with exit code: 0")
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
