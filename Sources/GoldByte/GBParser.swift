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
	
	func parse(_ code: String) -> ([[GBToken]]?, GBError?) {
		var code = code
		
		code.append("\n\n")
		
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
			} else if character == "\"" { //|| character == "#" || character == "|" {
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
			
			if wordNumber == 0 {
				if !headerMacros.contains(word) {
					isHeader = false
				}
				
				if word.isPlainText {
					if word == "exit" {
						currentLine.append(.exit_keyword)
					} else if word == "return" && expectsCodeBlock {
						currentLine.append(.return_keyword)
					} else if word == "var" {
						currentLine.append(.variable_keyword)
					} else if word == "const" {
						currentLine.append(.constant_keyword)
					} else if word == "if" && core.configuration.flags.contains(.allowMultiline) && expectsCodeBlock {
						currentLine.append(.if_keyword)
					} else if word == "struct" && core.configuration.flags.contains(.allowMultiline) {
						currentLine.append(.struct_keyword)
					} else if word == "namespace" && core.configuration.flags.contains(.allowMultiline) {
						currentLine.append(.namespace_keyword)
					} else if word == "while" && core.configuration.flags.contains(.allowMultiline) && expectsCodeBlock {
						currentLine.append(.while_keyword)
					} else if word == "func" && core.configuration.flags.contains(.allowMultiline) {
						currentLine.append(.function_keyword)
					} else {
						if !headerMacros.contains(word) {
							if word == "use" && core.configuration.flags.contains(.allowMultiline) {
								return (nil, .init(type: .panic, description: "Libraries are dissalowed.", line: lineNumber, word: wordNumber))
							}
							
							currentLine.append(.macro(word))
						} else if headerMacros.contains(word) && isHeader {
							currentLine.append(.macro(word))
						} else {
							return (nil, .init(type: .panic, description: "Header macros must only be used in header (before any other operation).", line: lineNumber, word: wordNumber))
						}
					}
				} else if word[word.range(of: #"[a-zA-Z:]+\([a-zA-Z.,:"_&%$#@!-+ 1-9\^&$+-~`]*\)"#, options: .regularExpression) ?? word.startIndex..<(word.index(word.startIndex, offsetBy: 0))] == word {
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
							} else if argumentPart.isPlainText {
								arguments.append(.init(value: argumentPart, type: .variable))
							} else {
								return (nil, .init(type: .panic, description: "Unexpected token: \(word).", line: lineNumber, word: wordNumber))
							}
						}
					}
					
					currentLine.append(.function_invocation(.init(name: name, arguments: arguments)))
				} else if word == "}" {
					if codeBlocks.count == 1 {
						currentLine.append(.code_block(codeBlocks[0]))
					} else {
						if let last = codeBlocks.last {
							codeBlocks[codeBlocks.endIndex - 2].append([.code_block(last)])
						} else {
							return (nil, .init(type: .panic, description: "Invalid block.", line: lineNumber, word: wordNumber))
						}
					}
					
					blocks -= 1
					
					if codeBlocks.count != 0 {
						codeBlocks.removeLast()
					}
					
					expectsCodeBlock = blocks != 0
				}
			} else {
				if word == "{" {
					blocks += 1
					codeBlocks.append([])
					expectsCodeBlock = true
				} else if hasStartedLogicalExpression {
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
						return (nil, .init(type: .panic, description: "Invalid element in logical epxression: \(word).", line: lineNumber, word: wordNumber))
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
							return (nil, .init(type: .panic, description: "Invalid element in logical epxression: \(word).", line: lineNumber, word: wordNumber))
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
							return (nil, .init(type: .panic, description: "Invalid element in logical epxression: \(word).", line: lineNumber, word: wordNumber))
						}
					} else {
						return (nil, .init(type: .panic, description: "Invalid arrangment of logical expression sign (#): \(word).", line: lineNumber, word: wordNumber))
					}
				} else if word == "|" || word.hasPrefix("|") || word.hasSuffix("|") {
					if !hasStartedEquation {
						hasStartedEquation = true
						
						if word.hasPrefix("|") {
							let withoutSymbol = word.replacingOccurrences(of: "|", with: "")
							
							if withoutSymbol.isNumber {
								equation.append(.number(Float(withoutSymbol)!))
							} else if withoutSymbol.isPlainText {
								equation.append(.variable(withoutSymbol))
							} else {
								return (nil, .init(type: .panic, description: "Invalid arrangment in equation: \(word).", line: lineNumber, word: wordNumber))
							}
							
							lastWasNumber = true
						}
					} else {
						hasStartedEquation = false
					
						if word.hasSuffix("|") {
							let withoutSymbol = word.replacingOccurrences(of: "|", with: "")
							
							if withoutSymbol.isNumber {
								equation.append(.number(Float(withoutSymbol)!))
							} else if withoutSymbol.isPlainText {
								equation.append(.variable(withoutSymbol))
							} else {
								return (nil, .init(type: .panic, description: "Invalid arrangment in equation: \(word).", line: lineNumber, word: wordNumber))
							}
							
							lastWasNumber = false
						}
						
						currentLine.append(.equation(.init(equation, storage: storage)))
						equation = []
					}
				} else if hasStartedEquation {
					if word.isNumber {
						if !lastWasNumber {
							equation.append(.number(Float(word)!))
							lastWasNumber = true
						} else {
							return (nil, .init(type: .panic, description: "Invalid arrangment in equation: \(word).", line: lineNumber, word: wordNumber))
						}
					} else if word.isPlainText {
						if !lastWasNumber {
							equation.append(.variable(word))
							lastWasNumber = true
						} else {
							return (nil, .init(type: .panic, description: "Invalid arrangment in equation: \(word).", line: lineNumber, word: wordNumber))
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
							return (nil, .init(type: .panic, description: "Invalid arrangment in equation: \(word).", line: lineNumber, word: wordNumber))
						}
					} else {
						return (nil, .init(type: .panic, description: "Invalid word in equation: \(word).", line: lineNumber, word: wordNumber))
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
									return (nil, .init(type: .panic, description: "Invalid token.", line: lineNumber, word: wordNumber))
								}
							} else {
								return (nil, .init(type: .panic, description: "Expected type annotation (NUMBER, STRING, etc), got \(type).", line: lineNumber, word: wordNumber))
							}
						} else {
							return (nil, .init(type: .panic, description: "Invalid token.", line: lineNumber, word: wordNumber))
						}
					} else {
						return (nil, .init(type: .panic, description: "Invalid token.", line: lineNumber, word: wordNumber))
					}
				} else if word.range(of: #"[a-zA-Z]+\([a-zA-Z:,]*\):[A-Z]+"#, options: .regularExpression) != nil {
					if word[word.range(of: #"[a-zA-Z]+\([a-zA-Z:,]*\):[A-Z]+"#, options: .regularExpression)!] == word {
						let returnType = word.components(separatedBy: ":").last!.trimmingCharacters(in: .whitespacesAndNewlines)
						
						if !returnType.isTypeAnnotation && returnType != "VOID" {
							return (nil, .init(type: .panic, description: "Return type should be any of type values (STRING, NUMBER, etc) or VOID.", line: lineNumber, word: wordNumber))
						}
						
						let name = word.components(separatedBy: "(")[0]
						
						let argumentParts = word.components(separatedBy: "(")[1].components(separatedBy: ")")[0].components(separatedBy: ",")
						
						var arguments = [GBFunctionArgumentDefinition]()
						
						if !argumentParts[0].isEmpty {
							for argumentPart in argumentParts {
								let parts = argumentPart.components(separatedBy: ":")
								
								if parts.count != 2 || !parts[0].isPlainText || !parts[1].isTypeAnnotation {
									return (nil, .init(type: .panic, description: "Invalid argument \"\(argumentPart)\" in function definition.", line: lineNumber, word: wordNumber))
								}
								
								arguments.append(GBFunctionArgumentDefinition(name: parts[0], type: .init(rawValue: parts[1])!))
							}
						}
						
						currentLine.append(.function_definition(.init(name: name, returnType: .init(rawValue: returnType)!, arguments: arguments)))
					} else {
						return (nil, .init(type: .panic, description: "Invalid token.", line: lineNumber, word: wordNumber))
					}
				} else if word.range(of: #"[a-zA-Z:]+\([a-zA-Z,0-9\"/: \^&$.?!]*\)"#, options: .regularExpression) != nil  && expectsCodeBlock {
					if word[word.range(of: #"[a-zA-Z:]+\([a-zA-Z,0-9\"/: \^&$.?!]*\)"#, options: .regularExpression)!] == word {
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
								} else if argumentPart.isPlainText {
									arguments.append(.init(value: argumentPart, type: .variable))
								} else {
									return (nil, .init(type: .panic, description: "Unexpected token: \(argumentPart).", line: lineNumber, word: wordNumber))
								}
							}
						}
						
						currentLine.append(.function_invocation(.init(name: name, arguments: arguments)))
					} else {
						return (nil, .init(type: .panic, description: "Invalid token: \(word).", line: lineNumber, word: wordNumber))
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
					if !word.isEmpty {
						currentLine.append(.plain_text(word))
					}
				} else if word.isURL {
					currentLine.append(.url(URL(string: word)!))
				} else {
					return (nil, .init(type: .panic, description: "Unexpected token: \(word).", line: lineNumber, word: wordNumber))
				}
			}
		}
		
		if expectsCodeBlock {
			return (nil, .init(type: .panic, description: "Didn't finish code block."))
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
	
	func prepare(withStorage storage: GBStorage, inNamespace namespace: String) -> String {
		var elements = self.replacingOccurrences(of: "\"", with: "").replacingOccurrences(of: "^564x7&$", with: "(").replacingOccurrences(of: "^564x8&$", with: ")").replacingOccurrences(of: "^564x9&$", with: ",").components(separatedBy: " ")
		
		elements = elements.map { element -> String in
			if element.hasPrefix("%(") && element.hasSuffix(")") {
				var element = element
				
				element.removeFirst(2)
				element.removeLast(1)
				
				var namespaces = element.components(separatedBy: "::")
				var key = namespaces.removeLast()
				
				if namespaces.count != 0 && namespaces[0] == "self" {
					namespaces.removeFirst()
					namespaces.insert(contentsOf: namespace.components(separatedBy: "::"), at: 0)
				}
				
				var seperator = namespaces.joined(separator: "::").isEmpty ? "" : "::"
				
				if namespaces.joined(separator: "::").hasSuffix("::") {
					seperator = ""
				}
				
				key = namespaces.joined(separator: "::") + seperator + key
				
				if storage.variableExists(key) {
					return storage[key].value
				}
			}
			
			var newElement = element
			
			if let range = newElement.range(of: #"%\([\S0-9^]+\)"#, options: .regularExpression) {
				var result = ""
				
				var rangeValue = String(newElement[range])
				
				rangeValue.removeFirst(2)
				rangeValue.removeLast(1)
				
				let variables = rangeValue.components(separatedBy: "|")
				
				for variable in variables {
					var namespaces = variable.components(separatedBy: "::")
					var key = namespaces.removeLast()
					
					if namespaces.count != 0 && namespaces[0] == "self" {
						namespaces.removeFirst()
						namespaces.insert(contentsOf: namespace.components(separatedBy: "::"), at: 0)
					}
					
					var seperator = namespaces.joined(separator: "::").isEmpty ? "" : "::"
					
					if namespaces.joined(separator: "::").hasSuffix("::") {
						seperator = ""
					}
					
					key = namespaces.joined(separator: "::") + seperator + key
					
					if storage.variableExists(key) {
						result.append(storage[key].value)
					}
				}
				
				newElement.replaceSubrange(range, with: result)
			}
			
			return newElement
		}
		
		return elements.joined(separator: " ")
	}
	
	var isString: Bool {
		self.hasPrefix("\"") && self.hasSuffix("\"")
	}
	
	var isPlainText: Bool {
		!isString && !self.contains(where: { "£§!@#$%^&*()+-={}[]|<>?;'\\,./~".contains($0) })
	}
	
	var isNumber: Bool {
		Float(self) != nil
	}
	
	var isBool: Bool {
		self == "true" || self == "false"
	}
	
	var isTypeAnnotation: Bool {
		return GBStorage.ValueType.allCases.map { $0.rawValue }.contains(self)
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
