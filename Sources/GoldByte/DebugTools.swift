//
//  Debug.swift
//  GoldByte
//
//  Created by Wiktor Wójcik on 25/11/2021.
//

import Foundation

class DebugTools {
	static func formatParsingResult(_ parsingOutput: [[GBToken]]) -> String {
		var result = ""
		
		for line in parsingOutput {
			var finishedLine = ""
			
			for word in line {
				finishedLine.append("\(word) ")
			}
			
			result.append(finishedLine + "\n")
		}
		
		result = result.replacingOccurrences(of: "GoldByte.GBToken.", with: "")
		result = result.replacingOccurrences(of: "GoldByte.GBStorage.ValueType.", with: "")
		result = result.replacingOccurrences(of: "GoldByte.", with: "")
		
		return result
	}
}
