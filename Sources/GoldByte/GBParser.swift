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
	}
	
	private func connectStrings(_ line: [String], lineNumber: Int) -> ([String]?, GBError?) {
		var newLine = [String]()
		
		var hasStartedString = false
		var string = ""
		
		for word in line {
			if (word.hasPrefix("\"") && word.hasSuffix("\"")) || (word == "\"\"") {
				newLine.append(word.replaceKeywordCharactersBetween())
			} else if word == "\"" && !hasStartedString {
				hasStartedString = true
			} else if word == "\"" && hasStartedString {
				newLine.append("\"" + string.replaceKeywordCharactersBetween() + "\"")
				hasStartedString = false
			} else if word.hasPrefix("\"") && !hasStartedString {
				hasStartedString = true
				string.append(word)
			} else if word.hasSuffix("\"") && hasStartedString {
				string.append(" " + word)
				
				newLine.append("\"" + string.replaceKeywordCharactersBetween() + "\"")
				
				hasStartedString = false
			} else if word.contains("\"") {
				if hasStartedString {
					string.append(" " + word)
					newLine.append(string.replaceKeywordCharactersBetween())
					hasStartedString = false
				} else {
					string.append(word)
					
					let countOfQuationMarks = word.count(of: "\"")
					
					if countOfQuationMarks != 0 && countOfQuationMarks % 2 == 0 {
						newLine.append(string.replaceKeywordCharactersBetween())
						hasStartedString = false
					} else {
						hasStartedString = true
					}
				}
			} else if hasStartedString {
				string.append(" " + word)
			} else {
				newLine.append(word)
			}
			
			if !hasStartedString {
				string = ""
			}
		}
		
		if hasStartedString {
			return (nil, .init(type: .parsing, description: "Started string but not finished.", line: lineNumber, word: 0))
		}
		
		return (newLine, nil)
	}
	
	func parse(_ code: String) -> ([[GBToken]]?, GBError?) {
		let code = code.replacingOccurrences(of: "\t", with: "")
		
		var result = [[GBToken]]()
		
		let lines = code.components(separatedBy: "\n").map { element -> String in
			if element.isEmpty {
				return "//"
			} else {
				return element
			}
		}
		
		
		var blocks: [GBBlock] = []
		var codeBlocks = [[[GBToken]]]()
		
		var expectsCodeBlock = false
		
		var isHeader = true

		for (lineNumber, line) in lines.enumerated() {
			if line.hasPrefix("//") {
				continue
			}
			
			var currentLine = [GBToken]()
			
			let (connectedStrings, error) = connectStrings(line.components(separatedBy: " "), lineNumber: lineNumber)
			
			if let error = error {
				return (nil, error)
			}
			
			let words = connectedStrings!
			
			var hasStartedEquation = false
			var hasStartedLogicalExpression = false
			
			var logicalExpressionElements = [GBLogicalElement]()
			var lastWasLogicalOperator = true
			
			var equation = [GBEquationSymbol]()
			var lastWasNumber = false

			let headerMacros = ["USE"]
			
			for (wordNumber, word) in words.enumerated() {
				if word.isEmpty {
					continue
				}
				
				if wordNumber == 0 {
					if !headerMacros.contains(word) {
						isHeader = false
					}
					
					if word.isPlainText {
						if word == "RETURN" && expectsCodeBlock {
							currentLine.append(.return_keyword)
						} else if word == "VAR" {
							currentLine.append(.variable_keyword)
						} else if word == "IF" && core.configuration.flags.contains(.allowMultiline) && expectsCodeBlock {
							currentLine.append(.if_keyword)
							blocks.append(.IF)
							codeBlocks.append([])
							expectsCodeBlock = true
						} else if word == "WHILE" && core.configuration.flags.contains(.allowMultiline) && expectsCodeBlock {
							currentLine.append(.while_keyword)
							blocks.append(.WHILE)
							codeBlocks.append([])
							expectsCodeBlock = true
						} else if word == "FN" && core.configuration.flags.contains(.allowMultiline) {
							currentLine.append(.function_keyword)
							blocks.append(.FUNCTION)
							codeBlocks.append([])
							expectsCodeBlock = true
						} else {
							if !headerMacros.contains(word) {
								if word == "USE" && core.configuration.flags.contains(.allowMultiline) {
									return (nil, .init(type: .parsing, description: "Libraries are dissalowed.", line: lineNumber, word: wordNumber))
								}
								
								currentLine.append(.macro(word))
							} else if headerMacros.contains(word) && isHeader {
								currentLine.append(.macro(word))
							} else {
								return (nil, .init(type: .parsing, description: "Header macros must only be used in header (before any other operation).", line: lineNumber, word: wordNumber))
							}
						}
					} else if word[word.range(of: #"[a-zA-Z]+\([a-zA-Z.,:"_&%$#@!-+ 1-9\^&$+-~`]*\)"#, options: .regularExpression) ?? word.startIndex..<(word.index(word.startIndex, offsetBy: 1))] == word {
						let name = word.components(separatedBy: "(")[0]
						
						let argumentParts = word.components(separatedBy: "(")[1].dropLast().components(separatedBy: ",")
						
						var arguments = [GBFunctionArgument]()
						
						if !argumentParts[0].isEmpty {
							for argumentPart in argumentParts {
								if argumentPart.isString {
									arguments.append(.init(value: argumentPart.replacingOccurrences(of: "\"", with: ""), type: .string))
								} else if argumentPart.isBool {
									arguments.append(.init(value: argumentPart, type: .bool))
								} else if argumentPart.isNumber {
									arguments.append(.init(value: argumentPart, type: .number))
								} else if argumentPart.isURL {
									arguments.append(.init(value: argumentPart, type: .url))
								} else {
									return (nil, .init(type: .parsing, description: "Unexpected token: \(word).", line: lineNumber, word: wordNumber))
								}
							}
						}
						
						currentLine.append(.function_invocation(.init(name: name, arguments: arguments)))
					} else if word == "/IF" {
						if blocks.last == .IF {
							if codeBlocks.count == 1 {
								currentLine.append(.code_block(codeBlocks[0]))
							} else {
								codeBlocks[codeBlocks.endIndex - 2].append([.code_block(codeBlocks.last!)])
							}
							
							blocks.removeLast()
							codeBlocks.removeLast()
							
							expectsCodeBlock = blocks.count != 0
						} else {
							return (nil, .init(type: .parsing, description: "Ending if construction before starting one.", line: lineNumber, word: wordNumber))
						}
					} else if word == "/WHILE" {
						if blocks.last == .WHILE {
							if codeBlocks.count == 1 {
								currentLine.append(.code_block(codeBlocks[0]))
							} else {
								codeBlocks[codeBlocks.endIndex - 2].append([.code_block(codeBlocks.last!)])
							}
							
							blocks.removeLast()
							codeBlocks.removeLast()
							
							expectsCodeBlock = blocks.count != 0
						} else {
							return (nil, .init(type: .parsing, description: "Ending while construction before starting one.", line: lineNumber, word: wordNumber))
						}
					} else if word == "/FN" {
						if blocks.last == .FUNCTION {
							if codeBlocks.count == 1 {
								currentLine.append(.code_block(codeBlocks[0]))
							} else {
								codeBlocks[codeBlocks.endIndex - 2].append([.code_block(codeBlocks.last!)])
							}
							
							blocks.removeLast()
							codeBlocks.removeLast()
							
							expectsCodeBlock = blocks.count != 0
						} else {
							return (nil, .init(type: .parsing, description: "Ending function before starting one.", line: lineNumber, word: wordNumber))
						}
					} else {
						return (nil, .init(type: .parsing, description: "Unexpected token: \(word).", line: lineNumber, word: wordNumber))
					}
				} else {
					if hasStartedLogicalExpression {
						var word = word
						var hasEnding = false
						
						if word == "#" {
							hasStartedLogicalExpression = false
							currentLine.append(.logical_expression(.init(logicalExpressionElements, storage: storage)))
							logicalExpressionElements = []
							continue
						}
						
						if word.hasSuffix("#") {
							hasStartedLogicalExpression = false
							hasEnding = true
							word = word.replacingOccurrences(of: "#", with: "")
						}
						
						if word.isLogicalOperator && !lastWasLogicalOperator {
							if word == "==" {
								logicalExpressionElements.append(.equals)
							} else if word == "||" {
								logicalExpressionElements.append(.or)
							} else if word == "&&" {
								logicalExpressionElements.append(.and)
							} else if word == ">" {
								logicalExpressionElements.append(.higherThan)
							} else if word == "<" {
								logicalExpressionElements.append(.lowerThan)
							} else if word == "!=" {
								logicalExpressionElements.append(.not_equals)
							}
							
							lastWasLogicalOperator = true
						} else if word.isBool && lastWasLogicalOperator {
							logicalExpressionElements.append(.value(.bool(Bool(word)!)))
							lastWasLogicalOperator = false
						} else if word.isNumber && lastWasLogicalOperator {
							logicalExpressionElements.append(.value(.number(Float(word)!)))
							lastWasLogicalOperator = false
						} else if word.isString && lastWasLogicalOperator {
							logicalExpressionElements.append(.value(.string(word.replacingOccurrences(of: "\"", with: ""))))
							lastWasLogicalOperator = false
						} else if word.isPlainText && lastWasLogicalOperator {
							logicalExpressionElements.append(.variable(word))
							lastWasLogicalOperator = false
						} else {
							return (nil, .init(type: .parsing, description: "Invalid element in logical epxression: \(word).", line: lineNumber, word: wordNumber))
						}
						
						if hasEnding {
							currentLine.append(.logical_expression(.init(logicalExpressionElements, storage: storage)))
							logicalExpressionElements = []
						}
					} else if word == "#" || word.hasPrefix("#") || word.hasSuffix("#") {
						if hasStartedLogicalExpression && word == "#" {
							currentLine.append(.logical_expression(.init(logicalExpressionElements, storage: storage)))
							hasStartedLogicalExpression = false
							logicalExpressionElements = []
						} else if !hasStartedLogicalExpression && word == "#" {
							hasStartedLogicalExpression = true
						} else if hasStartedLogicalExpression && word.hasSuffix("#") {
							let word = word.replacingOccurrences(of: "#", with: "")
							
							if word.isNumber && lastWasLogicalOperator {
								logicalExpressionElements.append(.value(.number(Float(word)!)))
								lastWasLogicalOperator = false
							} else if word.isString && lastWasLogicalOperator {
								logicalExpressionElements.append(.value(.string(word.replacingOccurrences(of: "\"", with: ""))))
								lastWasLogicalOperator = false
							} else if word.isPlainText && lastWasLogicalOperator {
								logicalExpressionElements.append(.variable(word))
								lastWasLogicalOperator = false
							} else {
								return (nil, .init(type: .parsing, description: "Invalid element in logical epxression: \(word).", line: lineNumber, word: wordNumber))
							}
							
							currentLine.append(.logical_expression(.init(logicalExpressionElements, storage: storage)))
							hasStartedLogicalExpression = false
							logicalExpressionElements = []
						} else if !hasStartedLogicalExpression && word.hasPrefix("#") {
							hasStartedLogicalExpression = true
							
							let word = word.replacingOccurrences(of: "#", with: "")
							
							if word.isNumber && lastWasLogicalOperator {
								logicalExpressionElements.append(.value(.number(Float(word)!)))
								lastWasLogicalOperator = false
							} else if word.isString && lastWasLogicalOperator {
								logicalExpressionElements.append(.value(.string(word.replacingOccurrences(of: "\"", with: ""))))
								lastWasLogicalOperator = false
							} else if word.isPlainText && lastWasLogicalOperator {
								logicalExpressionElements.append(.variable(word))
								lastWasLogicalOperator = false
							} else {
								return (nil, .init(type: .parsing, description: "Invalid element in logical epxression: \(word).", line: lineNumber, word: wordNumber))
							}
						} else {
							return (nil, .init(type: .parsing, description: "Invalid arrangment of logical expression sign (#): \(word).", line: lineNumber, word: wordNumber))
						}
					} else if word == "<" || word.hasPrefix("<") {
						if !hasStartedEquation {
							hasStartedEquation = true
							
							if word.hasPrefix("<") {
								let withoutSymbol = word.replacingOccurrences(of: "<", with: "")
								
								if withoutSymbol.isNumber {
									equation.append(.number(Float(withoutSymbol)!))
								} else if withoutSymbol.isPlainText {
									equation.append(.variable(withoutSymbol))
								} else {
									return (nil, .init(type: .parsing, description: "Invalid arrangment in equation: \(word).", line: lineNumber, word: wordNumber))
								}
																
								lastWasNumber = true
							}
						} else {
							return (nil, .init(type: .parsing, description: "Started equation before ending last.", line: lineNumber, word: wordNumber))
						}
					} else if word == ">" || word.hasSuffix(">") {
						if hasStartedEquation {
							hasStartedEquation = false
							
							if word.hasSuffix(">") {
								let withoutSymbol = word.replacingOccurrences(of: ">", with: "")
								
								if withoutSymbol.isNumber {
									equation.append(.number(Float(withoutSymbol)!))
								} else if withoutSymbol.isPlainText {
									equation.append(.variable(withoutSymbol))
								} else {
									return (nil, .init(type: .parsing, description: "Invalid arrangment in equation: \(word).", line: lineNumber, word: wordNumber))
								}
								
								lastWasNumber = false
							}
							
							currentLine.append(.equation(.init(equation, storage: storage)))
							equation = []
						} else {
							return (nil, .init(type: .parsing, description: "Ending equation before starting one.", line: lineNumber, word: wordNumber))
						}
					} else if hasStartedEquation {
						if word.isNumber {
							if !lastWasNumber {
								equation.append(.number(Float(word)!))
								lastWasNumber = true
							} else {
								return (nil, .init(type: .parsing, description: "Invalid arrangment in equation: \(word).", line: lineNumber, word: wordNumber))
							}
						} else if word.isPlainText {
							if !lastWasNumber {
								equation.append(.variable(word))
								lastWasNumber = true
							} else {
								return (nil, .init(type: .parsing, description: "Invalid arrangment in equation: \(word).", line: lineNumber, word: wordNumber))
							}
						} else if word.isMathSymbol {
							if lastWasNumber {
								if word == "+" {
									equation.append(.plus)
								} else if word == "*" {
									equation.append(.multiply)
								} else if word == "/" {
									equation.append(.divide)
								} else if word == "-" {
									equation.append(.minus)
								}
								
								lastWasNumber = false
							} else {
								return (nil, .init(type: .parsing, description: "Invalid arrangment in equation: \(word).", line: lineNumber, word: wordNumber))
							}
						} else {
							return (nil, .init(type: .parsing, description: "Invalid word in equation: \(word).", line: lineNumber, word: wordNumber))
						}
					} else if word.range(of: #"\([A-Z]+\)[a-zA-Z"1-9/~$]+"#, options: .regularExpression) != nil {
						if word[word.range(of: #"\([A-Z]+\)[a-zA-Z"1-9/~$]+"#, options: .regularExpression)!] == word {
							if let type = word.slice(from: "(", to: ")") {
								if let _ = GBToken.ValueType(rawValue: type) {
									let value = word.components(separatedBy: ")")[1]
									
									if value.isPointer {
										currentLine.append(.casted(.pointer(value.replacingOccurrences(of: "$", with: "")), .init(rawValue: type)!))
									} else if value.isString {
										currentLine.append(.casted(.string(value.replacingOccurrences(of: "\"", with: "")), .init(rawValue: type)!))
									} else if value.isNumber {
										currentLine.append(.casted(.string(value.replacingOccurrences(of: "\"", with: "")), .init(rawValue: type)!))
									} else if value.isBool {
										currentLine.append(.casted(.string(value.replacingOccurrences(of: "\"", with: "")), .init(rawValue: type)!))
									} else if value.isURL {
										currentLine.append(.casted(.string(value.replacingOccurrences(of: "\"", with: "")), .init(rawValue: type)!))
									} else {
										return (nil, .init(type: .parsing, description: "Invalid token.", line: lineNumber, word: wordNumber))
									}
								} else {
									return (nil, .init(type: .parsing, description: "Expected type annotation (NUMBER, STRING, etc), got \(type).", line: lineNumber, word: wordNumber))
								}
							} else {
								return (nil, .init(type: .parsing, description: "Invalid token.", line: lineNumber, word: wordNumber))
							}
						} else {
							return (nil, .init(type: .parsing, description: "Invalid token.", line: lineNumber, word: wordNumber))
						}
					} else if word.range(of: #"[a-zA-Z]+\([a-zA-Z:,]*\):[A-Z]+"#, options: .regularExpression) != nil {
						if word[word.range(of: #"[a-zA-Z]+\([a-zA-Z:,]*\):[A-Z]+"#, options: .regularExpression)!] == word {
							let returnType = word.components(separatedBy: ":").last!.trimmingCharacters(in: .whitespacesAndNewlines)
							
							if !returnType.isTypeAnnotation && returnType != "VOID" {
								return (nil, .init(type: .parsing, description: "Return type should be any of type values (STRING, NUMBER, etc) or VOID.", line: lineNumber, word: wordNumber))
							}
							
							let name = word.components(separatedBy: "(")[0]
							
							let argumentParts = word.components(separatedBy: "(")[1].components(separatedBy: ")")[0].components(separatedBy: ",")
							
							var arguments = [GBFunctionArgumentDefinition]()
							
							if !argumentParts[0].isEmpty {
								for argumentPart in argumentParts {
									let parts = argumentPart.components(separatedBy: ":")
									
									if parts.count != 2 || !parts[0].isPlainText || !parts[1].isTypeAnnotation {
										return (nil, .init(type: .parsing, description: "Invalid argument \"\(argumentPart)\" in function definition.", line: lineNumber, word: wordNumber))
									}
									
									arguments.append(GBFunctionArgumentDefinition(name: parts[0], type: .init(rawValue: parts[1])!))
								}
							}
							
							currentLine.append(.function_definition(.init(name: name, returnType: .init(rawValue: returnType)!, arguments: arguments)))
						} else {
							return (nil, .init(type: .parsing, description: "Invalid token.", line: lineNumber, word: wordNumber))
						}
					} else if word.range(of: #"[a-zA-Z]+\([a-zA-Z,0-9\"/: \^&$.?!]*\)"#, options: .regularExpression) != nil {
						if word[word.range(of: #"[a-zA-Z]+\([a-zA-Z,0-9\"/: \^&$.?!]*\)"#, options: .regularExpression)!] == word {
							let name = word.components(separatedBy: "(")[0]
							
							let argumentParts = word.components(separatedBy: "(")[1].dropLast().components(separatedBy: ",")
							
							var arguments = [GBFunctionArgument]()
							if !argumentParts[0].isEmpty {
								for argumentPart in argumentParts {
									if argumentPart.isString {
										arguments.append(.init(value: argumentPart.replacingOccurrences(of: "\"", with: ""), type: .string))
									} else if argumentPart.isBool {
										arguments.append(.init(value: argumentPart, type: .bool))
									} else if argumentPart.isNumber {
										arguments.append(.init(value: argumentPart, type: .number))
									} else if argumentPart.isURL {
										arguments.append(.init(value: argumentPart, type: .url))
									} else {
										return (nil, .init(type: .parsing, description: "Unexpected token: \(argumentPart).", line: lineNumber, word: wordNumber))
									}
								}
							}
							
							currentLine.append(.function_invocation(.init(name: name, arguments: arguments)))
						} else {
							return (nil, .init(type: .parsing, description: "Invalid token.", line: lineNumber, word: wordNumber))
						}
					} else if word.isString {
						currentLine.append(.string(word.replacingOccurrences(of: "\"", with: "")))
					} else if word.isBool {
						currentLine.append(.bool(Bool(word)!))
					} else if word.isTypeAnnotation {
						currentLine.append(.variable_type(.init(rawValue: word)!))
					} else if word.isNumber {
						currentLine.append(.number(Float(word)!))
					} else if word.isPointer {
						currentLine.append(.pointer(word.replacingOccurrences(of: "$", with: "")))
					} else if word.isPlainText {
						currentLine.append(.plain_text(word))
					} else if word.isURL {
						currentLine.append(.url(URL(string: word)!))
					} else {
						return (nil, .init(type: .parsing, description: "Unexpected token: \(word).", line: lineNumber, word: wordNumber))
					}
				}
			}
			
			if !currentLine.isEmpty {
				if expectsCodeBlock {
					var firstIsKeyword = false
					
					switch currentLine.first! {
						case .if_keyword:
							firstIsKeyword = true
						case .function_keyword:
							firstIsKeyword = true
						case .while_keyword:
							firstIsKeyword = true
						default:
							firstIsKeyword = false
					}
					
					if blocks.count > 1 {
						if firstIsKeyword {
							codeBlocks[codeBlocks.endIndex - 2].append(currentLine)
						} else {
							codeBlocks[codeBlocks.endIndex - 1].append(currentLine)
						}
					} else if blocks.count == 1 {
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
		}
		
		if expectsCodeBlock {
			return (nil, .init(type: .parsing, description: "Didn't finish code block."))
		}
		
		return (result, nil)
	}
}

extension String {
	func replaceKeywordCharacters() -> String {
		self.replacingOccurrences(of: ",", with: "^564x8&$").replacingOccurrences(of: ")", with: "^564x8&$").replacingOccurrences(of: "(", with: "^564x7&$")
	}
	
	func replaceKeywordCharactersBetween() -> String {
		self.replacingOccurrences(of: ",", with: "^564x8&$", between: "\"").replacingOccurrences(of: ")", with: "^564x8&$", between: "\"").replacingOccurrences(of: "(", with: "^564x7&$", between: "\"")
	}
	
	func prepare(withStorage storage: GBStorage) -> String {
		var elements = self.replacingOccurrences(of: "^564x7&$", with: "(").replacingOccurrences(of: "^564x8&$", with: ")").replacingOccurrences(of: "^564x9&$", with: ",").components(separatedBy: " ")
		
		elements = elements.map { element -> String in
			if element.hasPrefix("%(") && element.hasSuffix(")") {
				var element = element
				
				element.removeFirst(2)
				element.removeLast(1)
				
				if storage.variableExists(element) {
					return storage[element].value
				}
			} else if let range = element.range(of: #"%\([a-zA-Z]+\)"#, options: .regularExpression) {
				var element = element
				
				var rangeValue = String(element[range])
				
				rangeValue.removeFirst(2)
				rangeValue.removeLast(1)

				if storage.variableExists(rangeValue) {
					element.replaceSubrange(range, with: storage[rangeValue].value)
					return element
				}
			}
			
			return element
		}
		
		return elements.joined(separator: " ")
	}
	
	var isString: Bool {
		self.hasPrefix("\"") && self.hasSuffix("\"")
	}
	
	var isPlainText: Bool {
		!isString && !self.contains(where: { "£§!@#$%^&*()+-={}[]:|<>?;'\\,./~".contains($0) })
	}
	
	var isNumber: Bool {
		Int(self) != nil
	}
	
	var isBool: Bool {
		self == "true" || self == "false"
	}
	
	var isTypeAnnotation: Bool {
		GBStorage.ValueType.allCases.map { $0.rawValue }.contains(self)
	}
	
	var isPointer: Bool {
		hasPrefix("$")
	}
	
	var isMathSymbol: Bool {
		"+-*/".contains(self)
	}
	
	var isURL: Bool {
		URL(string: self) != nil
	}
	
	var isLogicalOperator: Bool {
		GBLogicalExpression.operators.contains(self)
	}
	
	func replacingOccurrences(of: String, with: String, between: Character) -> String {
		var isBetween = false
		var result = ""
		
		for character in self {
			if character == between {
				isBetween.toggle()
			} else if isBetween {
				result.append(String(character) == of ? String(with) : String(character))
				continue
			}
			
			result.append(String(character))
		}
		
		return result
	}
	
	func count(of searchedCharacter: Character) -> Int {
		var count = 0
		
		for character in self {
			count += character == searchedCharacter ? 1 : 0
		}
		
		return count
	}
	
	func slice(from: String, to: String) -> String? {
		(range(of: from)?.upperBound).flatMap { substringFrom in
			(range(of: to, range: substringFrom..<endIndex)?.lowerBound).map { substringTo in
				String(self[substringFrom..<substringTo])
			}
		}
	}
	
	func detectType() -> GBStorage.ValueType {
		if isString {
			return .string
		} else if isNumber {
			return .number
		} else if isBool {
			return .bool
		} else {
			return .string
		}
	}
}
