//
//  GBErrorHandler.swift
//  GoldByte
//
//  Created by Wiktor Wójcik on 24/11/2021.
//

import Foundation

protocol GBErrorHandler {
	func handle(_ error: GBError)
}

public struct GBError {
	public enum ErrorType: String {
		case panic = "panic"
		case thrown = "thrown"
	}
	
	var type: ErrorType
	var description: String
	
	var line: Int
	var word: Int
	
	init(type: ErrorType, description: String) {
		self.type = type
		self.description = description
		
		line = 1
		word = 1
	}
	
	init(type: ErrorType, description: String, line: Int, word: Int) {
		self.type = type
		self.description = description
		self.line = line
		self.word = word
	}
}
