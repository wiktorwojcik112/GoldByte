//
//  GBDebug.swift
//  GoldByte
//
//  Created by Wiktor Wójcik on 05/12/2021.
//

import Foundation

class GBDebugger {
	init(storage: GBStorage) {
		self.storage = storage
	}
	
	var storage: GBStorage
	var breakpoints: [Int] = []
	
	var file: String = ""
	
	let core = GBCore.shared
	
	func debug(code: String, filePath: String) {
		print("GoldByte 1.0 Debugger by Wiktor Wójcik\nType :exit to exit.")
		while true {
			print("\(file) >> ", terminator: "")
			let line = readLine()! + "\n"
			
			if line.trimmingCharacters(in: .whitespacesAndNewlines) == ":exit" {
				exit(0)
			}
			
			core.start(withCode: line, filePath: "")
		}
	}
}
