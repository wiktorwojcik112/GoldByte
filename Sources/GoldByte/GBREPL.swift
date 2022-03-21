//
//  GBREPL.swift
//  GoldByte
//
//  Created by Wiktor Wójcik on 30/11/2021.
//

import Foundation

public class GBREPL {
	typealias GBMacroAction = GBCore.GBMacroAction
	
	let fileManager = FileManager.default
	var core: GBCore
	
	public init() {
		core = GBCore(configuration: GBCore.defaultConfiguration, macros: nil)
		core.configuration.flags = [.noMain]
		core.configuration.console = REPLConsole()
	}
	
	public func start() {
		print("GoldByte \(core.version) by Wiktor Wójcik\nType :exit to exit.")
		while true {
			print(">> ", terminator: "")
			let line = readLine()! + "\n"
			
			if line.trimmingCharacters(in: .whitespacesAndNewlines) == ":exit" {
				exit(0)
			}
			
			core.start(withCode: line, filePath: "")
		}
	}
}

class REPLConsole: GBConsole {
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
