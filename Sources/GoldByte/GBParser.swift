//
//  GBParser.swift
//  GoldByte
//
//  Created by Wiktor Wójcik on 24/11/2021.
//

import Foundation

class GBParser {
	var core: GBCore!
	var errorHandler: GBErrorHandler
	var storage: GBStorage
	
	init(_ core: GBCore?, errorHandler: GBErrorHandler, storage: GBStorage) {
		self.core = core
		self.errorHandler = errorHandler
		self.storage = storage
		
		self.wordParsers = []
		self.wordParsers = [MacroParser(parser: self), FunctionInvocationParser(parser: self), BracketsParser(parser: self), LogicalExpressionParser(parser: self), EquationParser(parser: self), CastingParser(parser: self), FunctionDefinitionParser(parser: self), StringParser(parser: self), BoolParser(parser: self), NumberParser(parser: self), PointerParser(parser: self), TypeAnnotationParser(parser: self), PlainTextParser(parser: self), URLParser(parser: self)]
	}
	
	var result = [[GBToken]]()
	
	var blocks = 0
	var codeBlocks = [[[GBToken]]]()
	
	var expectsCodeBlock = false
	
	var isHeader = true
	
	var currentLine = [GBToken]()
	
	var hasStartedEquation = false
	var hasStartedLogicalExpression = false
	
	var logicalExpressionElements = [GBLogicalElement]()
	var lastWasLogicalOperator = true
	
	var equation = [GBEquationSymbol]()
	var lastWasNumber = false
	
	let headerMacros = ["use"]
	
	var lineNumber = 0
	var wordNumber = 0
	var word = ""
	
	var ignoreLine = false
	var includeSpace = false
	var parsedLastWord = false
	var isEndOfTheLine = false
	var isBeginningOfTheLine = true
	
	private var wordParsers: [WordParser]
	
	func parse(_ code: String) -> ([[GBToken]]?, GBError?) {
		var code = code
		
		code.append("\n\n")
		
		result = [[GBToken]]()
		
		blocks = 0
		codeBlocks = [[[GBToken]]]()
		
		expectsCodeBlock = false
		
		isHeader = true
		
		currentLine = [GBToken]()
		
		hasStartedEquation = false
		hasStartedLogicalExpression = false
		
		logicalExpressionElements = [GBLogicalElement]()
		lastWasLogicalOperator = true
		
		equation = [GBEquationSymbol]()
		lastWasNumber = false
		
		lineNumber = 0
		wordNumber = 0
		word = ""
		
		var ignoreLine = false
		var includeSpace = false
		var parsedLastWord = false
		var isEndOfTheLine = false
		var isBeginningOfTheLine = true
		
		for character in code {
			defer {
				if parsedLastWord {
					word = ""
					if !isBeginningOfTheLine {
						wordNumber += 1
					}
					parsedLastWord = false
					
					if isEndOfTheLine {
						if !currentLine.isEmpty {
							if expectsCodeBlock {
								var firstIsKeyword = false
								
								switch currentLine.first! {
									case .if_keyword, .function_keyword, .while_keyword, .namespace_keyword, .struct_keyword:
										firstIsKeyword = true
									default:
										firstIsKeyword = false
								}
								
								if blocks > 1 {
									if firstIsKeyword {
										codeBlocks[codeBlocks.endIndex - 2].append(currentLine)
									} else {
										codeBlocks[codeBlocks.endIndex - 1].append(currentLine)
									}
								} else if blocks == 1 {
									if firstIsKeyword {
										result.append(currentLine)
									} else {
										codeBlocks[codeBlocks.endIndex - 1].append(currentLine)
									}
								} else {
									result.append(currentLine)
								}
							} else {
								result.append(currentLine)
							}
						}
						
						lineNumber += 1
						hasStartedEquation = false
						hasStartedLogicalExpression = false
						logicalExpressionElements = [GBLogicalElement]()
						lastWasLogicalOperator = true
						equation = [GBEquationSymbol]()
						lastWasNumber = false
						ignoreLine = false
						isBeginningOfTheLine = true
						wordNumber = 0
						isEndOfTheLine = false
						currentLine = []
					}
				}
			}
			
			if character == "\n" {
				isEndOfTheLine = true
				parsedLastWord = true
				
				if ignoreLine {
					continue
				}
			} else if ignoreLine {
				continue
			} else if character == "\"" {
				includeSpace = !includeSpace
				word.append(character)
				continue
			} else if character == " " {
				if includeSpace {
					word.append(" ")
					continue
				}
		
				parsedLastWord = true
			} else if character == "\t" {
				continue
			} else {
				isBeginningOfTheLine = false
				word.append(character)
				continue
			}
			
			if word.hasPrefix("//") {
				ignoreLine = true
				continue
			}
			
			if word.isEmpty {
				continue
			}
			
			for parser in wordParsers {
				if parser.isProper(word: word) {
					if let error = parser.parse(word: word) {
						return (nil, error)
					}
					
					break
				} else {
					continue
				}
			}
		}
		
		if expectsCodeBlock {
			return (nil, .init(type: .panic, description: "Didn't finish code block."))
		}
		
		return (result, nil)
	}
}
