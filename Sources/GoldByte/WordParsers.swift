//
//  WordParsers.swift
//  
//
//  Created by Wiktor Wójcik on 22/03/2022.
//

import Foundation

protocol WordParser {
	var parser: GBParser { get set }
	
	func isProper(word: String) -> Bool
	func parse(word: String) -> GBError?
}

struct MacroParser: WordParser {
	var parser: GBParser
	
	func isProper(word: String) -> Bool {
		if parser.wordNumber == 0 {
			if !parser.headerMacros.contains(word) {
				parser.isHeader = false
			}
			
			return word.isPlainText
		} else {
			return false
		}
	}
	
	func parse(word: String) -> GBError? {
		if word == "exit" {
			parser.currentLine.append(.exit_keyword)
		} else if word == "return" && parser.expectsCodeBlock {
			parser.currentLine.append(.return_keyword)
		} else if word == "var" {
			parser.currentLine.append(.variable_keyword)
		} else if word == "const" {
			parser.currentLine.append(.constant_keyword)
		} else if word == "if" && parser.core.configuration.flags.contains(.allowMultiline) && parser.expectsCodeBlock {
			parser.currentLine.append(.if_keyword)
		} else if word == "struct" && parser.core.configuration.flags.contains(.allowMultiline) {
			parser.currentLine.append(.struct_keyword)
		} else if word == "namespace" && parser.core.configuration.flags.contains(.allowMultiline) {
			parser.currentLine.append(.namespace_keyword)
		} else if word == "while" && parser.core.configuration.flags.contains(.allowMultiline) && parser.expectsCodeBlock {
			parser.currentLine.append(.while_keyword)
		} else if word == "func" && parser.core.configuration.flags.contains(.allowMultiline) {
			parser.currentLine.append(.function_keyword)
		} else {
			if !parser.headerMacros.contains(word) {
				if word == "use" && parser.core.configuration.flags.contains(.allowMultiline) {
					return .init(type: .panic, description: "Libraries are dissalowed.", line: parser.lineNumber, word: parser.wordNumber)
				}
				
				parser.currentLine.append(.macro(word))
			} else if parser.headerMacros.contains(word) && parser.isHeader {
				parser.currentLine.append(.macro(word))
			} else {
				return .init(type: .panic, description: "Header macros must only be used in header (before any other operation).", line: parser.lineNumber, word: parser.wordNumber)
			}
		}
		
		return nil
	}

}

struct FunctionInvocationParser: WordParser {
	var parser: GBParser
	
	let regex = #"[a-zA-Z:@]+\([a-zA-Z,0-9\"/: \^&$.?!]*\)"#
	
	func isProper(word: String) -> Bool {
		if word.range(of: regex, options: .regularExpression) != nil  && parser.expectsCodeBlock {
			if word[word.range(of: regex, options: .regularExpression)!] == word {
				return true
			}
		}
		
		return false
	}
	
	func parse(word: String) -> GBError? {
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
					return .init(type: .panic, description: "Unexpected token: \(argumentPart).", line: parser.lineNumber, word: parser.wordNumber)
				}
			}
		}
		
		parser.currentLine.append(.function_invocation(.init(name: name, arguments: arguments)))
		
		return nil
	}
}

struct BracketsParser: WordParser {
	var parser: GBParser
	
	func isProper(word: String) -> Bool {
		return (parser.wordNumber == 0 && word == "}") || word == "{"
	}
	
	func parse(word: String) -> GBError? {
		if word == "{" {
			parser.blocks += 1
			parser.codeBlocks.append([])
			parser.expectsCodeBlock = true
		} else if word == "}" {
			if parser.codeBlocks.count == 1 {
				parser.currentLine.append(.code_block(parser.codeBlocks[0]))
			} else {
				if let last = parser.codeBlocks.last {
					parser.codeBlocks[parser.codeBlocks.endIndex - 2].append([.code_block(last)])
				} else {
					print(word)
					return .init(type: .panic, description: "Invalid block.", line: parser.lineNumber, word: parser.wordNumber)
				}
			}
			
			parser.blocks -= 1
			
			if parser.codeBlocks.count != 0 {
				parser.codeBlocks.removeLast()
			}
			
			parser.expectsCodeBlock = parser.blocks != 0
		}
		
		return nil
	}
}

struct LogicalExpressionParser: WordParser {
	var parser: GBParser
	
	func isProper(word: String) -> Bool {
		return (parser.hasStartedLogicalExpression) || (word == "#" || word.hasPrefix("#") || word.hasSuffix("#"))
	}
	
	func parse(word: String) -> GBError? {
		if parser.hasStartedLogicalExpression {
			var word = word
			var hasEnding = false
			
			if word == "#" {
				parser.hasStartedLogicalExpression = false
				parser.currentLine.append(.logical_expression(.init(parser.logicalExpressionElements, storage: parser.storage)))
				parser.logicalExpressionElements = []
				
				return nil
			}
			
			if word.hasSuffix("#") {
				parser.hasStartedLogicalExpression = false
				hasEnding = true
				word = word.replacingOccurrences(of: "#", with: "")
			}
			
			if word.isLogicalOperator && !parser.lastWasLogicalOperator {
				if word == "==" {
					parser.logicalExpressionElements.append(.equals)
				} else if word == "||" {
					parser.logicalExpressionElements.append(.or)
				} else if word == "&&" {
					parser.logicalExpressionElements.append(.and)
				} else if word == ">" {
					parser.logicalExpressionElements.append(.higherThan)
				} else if word == "<" {
					parser.logicalExpressionElements.append(.lowerThan)
				} else if word == "!=" {
					parser.logicalExpressionElements.append(.not_equals)
				}
				
				parser.lastWasLogicalOperator = true
			} else if word.isBool && parser.lastWasLogicalOperator {
				parser.logicalExpressionElements.append(.value(.bool(Bool(word)!)))
				parser.lastWasLogicalOperator = false
			} else if word.isNumber && parser.lastWasLogicalOperator {
				parser.logicalExpressionElements.append(.value(.number(Float(word)!)))
				parser.lastWasLogicalOperator = false
			} else if word.isString && parser.lastWasLogicalOperator {
				parser.logicalExpressionElements.append(.value(.string(word.replacingOccurrences(of: "\"", with: ""))))
				parser.lastWasLogicalOperator = false
			} else if word.isPlainText && parser.lastWasLogicalOperator {
				parser.logicalExpressionElements.append(.variable(word))
				parser.lastWasLogicalOperator = false
			} else {
				return .init(type: .panic, description: "Invalid element in logical epxression: \(word).", line: parser.lineNumber, word: parser.wordNumber)
			}
			
			if hasEnding {
				parser.currentLine.append(.logical_expression(.init(parser.logicalExpressionElements, storage: parser.storage)))
				parser.logicalExpressionElements = []
			}
		} else if word == "#" || word.hasPrefix("#") || word.hasSuffix("#") {
			if parser.hasStartedLogicalExpression && word == "#" {
				parser.currentLine.append(.logical_expression(.init(parser.logicalExpressionElements, storage: parser.storage)))
				parser.hasStartedLogicalExpression = false
				parser.logicalExpressionElements = []
			} else if !parser.hasStartedLogicalExpression && word == "#" {
				parser.hasStartedLogicalExpression = true
			} else if parser.hasStartedLogicalExpression && word.hasSuffix("#") {
				let word = word.replacingOccurrences(of: "#", with: "")
				
				if word.isNumber && parser.lastWasLogicalOperator {
					parser.logicalExpressionElements.append(.value(.number(Float(word)!)))
					parser.lastWasLogicalOperator = false
				} else if word.isString && parser.lastWasLogicalOperator {
					parser.logicalExpressionElements.append(.value(.string(word.replacingOccurrences(of: "\"", with: ""))))
					parser.lastWasLogicalOperator = false
				} else if word.isPlainText && parser.lastWasLogicalOperator {
					parser.logicalExpressionElements.append(.variable(word))
					parser.lastWasLogicalOperator = false
				} else {
					return .init(type: .panic, description: "Invalid element in logical epxression: \(word).", line: parser.lineNumber, word: parser.wordNumber)
				}
				
				parser.currentLine.append(.logical_expression(.init(parser.logicalExpressionElements, storage: parser.storage)))
				parser.hasStartedLogicalExpression = false
				parser.logicalExpressionElements = []
			} else if !parser.hasStartedLogicalExpression && word.hasPrefix("#") {
				parser.hasStartedLogicalExpression = true
				
				let word = word.replacingOccurrences(of: "#", with: "")
				
				if word.isNumber && parser.lastWasLogicalOperator {
					parser.logicalExpressionElements.append(.value(.number(Float(word)!)))
					parser.lastWasLogicalOperator = false
				} else if word.isString && parser.lastWasLogicalOperator {
					parser.logicalExpressionElements.append(.value(.string(word.replacingOccurrences(of: "\"", with: ""))))
					parser.lastWasLogicalOperator = false
				} else if word.isPlainText && parser.lastWasLogicalOperator {
					parser.logicalExpressionElements.append(.variable(word))
					parser.lastWasLogicalOperator = false
				} else {
					return .init(type: .panic, description: "Invalid element in logical epxression: \(word).", line: parser.lineNumber, word: parser.wordNumber)
				}
			} else {
				return .init(type: .panic, description: "Invalid arrangment of logical expression sign (#): \(word).", line: parser.lineNumber, word: parser.wordNumber)
			}
		}
		
		return nil
	}
}

struct EquationParser: WordParser {
	var parser: GBParser
	
	func isProper(word: String) -> Bool {
		return (parser.hasStartedEquation) || (word == "|" || word.hasPrefix("|") || word.hasSuffix("|"))
	}
	
	func parse(word: String) -> GBError? {
		if word == "|" || word.hasPrefix("|") || word.hasSuffix("|") {
			if !parser.hasStartedEquation {
				parser.hasStartedEquation = true
				
				if word.hasPrefix("|") {
					let withoutSymbol = word.replacingOccurrences(of: "|", with: "")
					
					if withoutSymbol.isNumber {
						parser.equation.append(.number(Float(withoutSymbol)!))
					} else if withoutSymbol.isPlainText {
						parser.equation.append(.variable(withoutSymbol))
					} else {
						return .init(type: .panic, description: "Invalid arrangment in equation: \(word).", line: parser.lineNumber, word: parser.wordNumber)
					}
					
					parser.lastWasNumber = true
				}
			} else {
				parser.hasStartedEquation = false
				
				if word.hasSuffix("|") {
					let withoutSymbol = word.replacingOccurrences(of: "|", with: "")
					
					if withoutSymbol.isNumber {
						parser.equation.append(.number(Float(withoutSymbol)!))
					} else if withoutSymbol.isPlainText {
						parser.equation.append(.variable(withoutSymbol))
					} else {
						return .init(type: .panic, description: "Invalid arrangment in equation: \(word).", line: parser.lineNumber, word: parser.wordNumber)
					}
					
					parser.lastWasNumber = false
				}
				
				parser.currentLine.append(.equation(.init(parser.equation, storage: parser.storage)))
				parser.equation = []
			}
		} else if parser.hasStartedEquation {
			if word.isNumber {
				if !parser.lastWasNumber {
					parser.equation.append(.number(Float(word)!))
					parser.lastWasNumber = true
				} else {
					return .init(type: .panic, description: "Invalid arrangment in equation: \(word).", line: parser.lineNumber, word: parser.wordNumber)
				}
			} else if word.isPlainText {
				if !parser.lastWasNumber {
					parser.equation.append(.variable(word))
					parser.lastWasNumber = true
				} else {
					return .init(type: .panic, description: "Invalid arrangment in equation: \(word).", line: parser.lineNumber, word: parser.wordNumber)
				}
			} else if word.isMathSymbol {
				if parser.lastWasNumber {
					if word == "+" {
						parser.equation.append(.plus)
					} else if word == "*" {
						parser.equation.append(.multiply)
					} else if word == "/" {
						parser.equation.append(.divide)
					} else if word == "-" {
						parser.equation.append(.minus)
					} else if word == "%" {
						parser.equation.append(.modulo)
					}
					
					parser.lastWasNumber = false
				} else {
					return .init(type: .panic, description: "Invalid arrangment in equation: \(word).", line: parser.lineNumber, word: parser.wordNumber)
				}
			} else {
				return .init(type: .panic, description: "Invalid word in equation: \(word).", line: parser.lineNumber, word: parser.wordNumber)
			}
		}
		
		return nil
	}
}

struct CastingParser: WordParser {
	var parser: GBParser
	
	var regex = #"\([A-Z]+\)[a-zA-Z"1-9/~$]+"#
	
	func isProper(word: String) -> Bool {
		if word.range(of: regex, options: .regularExpression) != nil {
			if word[word.range(of: regex, options: .regularExpression)!] == word {
				if word.slice(from: "(", to: ")") != nil {
					return true
				}
			}
		}
		
		return false
	}
	
	func parse(word: String) -> GBError? {
		let type = word.slice(from: "(", to: ")")!
		
		if let _ = GBToken.ValueType(rawValue: type) {
			let value = word.components(separatedBy: ")")[1]
			
			if value.isPointer {
				parser.currentLine.append(.casted(.pointer(value.replacingOccurrences(of: "$", with: "")), .init(rawValue: type)!))
			} else if value.isString {
				parser.currentLine.append(.casted(.string(value.replacingOccurrences(of: "\"", with: "")), .init(rawValue: type)!))
			} else if value.isNumber {
				parser.currentLine.append(.casted(.string(value.replacingOccurrences(of: "\"", with: "")), .init(rawValue: type)!))
			} else if value.isBool {
				parser.currentLine.append(.casted(.string(value.replacingOccurrences(of: "\"", with: "")), .init(rawValue: type)!))
			} else if value.isURL {
				parser.currentLine.append(.casted(.string(value.replacingOccurrences(of: "\"", with: "")), .init(rawValue: type)!))
			} else {
				return .init(type: .panic, description: "Invalid token.", line: parser.lineNumber, word: parser.wordNumber)
			}
		} else {
			return .init(type: .panic, description: "Expected type annotation (NUMBER, STRING, etc), got \(type).", line: parser.lineNumber, word: parser.wordNumber)
		}
		
		return nil
	}
}

struct FunctionDefinitionParser: WordParser {
	var parser: GBParser
	
	func isProper(word: String) -> Bool {
		if word.range(of: #"[a-zA-Z:]+\([a-zA-Z,0-9\"/: \^&$.?!]*\):[A-Z]+"#, options: .regularExpression) != nil {
			if word[word.range(of: #"[a-zA-Z]+\([a-zA-Z,0-9\"/: \^&$.?!]*\):[A-Z]+"#, options: .regularExpression)!] == word {
				return true
			}
		}
		
		return false
	}
	
	func parse(word: String) -> GBError? {
		let returnType = word.components(separatedBy: ":").last!.trimmingCharacters(in: .whitespacesAndNewlines)
		
		if !returnType.isTypeAnnotation && returnType != "VOID" {
			return .init(type: .panic, description: "Return type should be any of type values (STRING, NUMBER, etc) or VOID.", line: parser.lineNumber, word: parser.wordNumber)
		}
		
		let name = word.components(separatedBy: "(")[0]
		
		let argumentParts = word.components(separatedBy: "(")[1].components(separatedBy: ")")[0].components(separatedBy: ",")
		
		var arguments = [GBFunctionArgumentDefinition]()
		
		if !argumentParts[0].isEmpty {
			for argumentPart in argumentParts {
				let parts = argumentPart.components(separatedBy: ":")
				
				if parts.count != 2 || !parts[0].isPlainText || !parts[1].isTypeAnnotation {
					return .init(type: .panic, description: "Invalid argument \"\(argumentPart)\" in function definition.", line: parser.lineNumber, word: parser.wordNumber)
				}
				
				arguments.append(GBFunctionArgumentDefinition(name: parts[0], type: .init(rawValue: parts[1])!))
			}
		}
		
		parser.currentLine.append(.function_definition(.init(name: name, returnType: .init(rawValue: returnType)!, arguments: arguments)))
		
		return nil
	}
}

struct StringParser: WordParser {
	var parser: GBParser
	
	func isProper(word: String) -> Bool {
		return word.isString
	}
	
	func parse(word: String) -> GBError? {
		let word = String(word.dropFirst().dropLast())
		parser.currentLine.append(.string(word))
		
		return nil
	}
}

struct BoolParser: WordParser {
	var parser: GBParser
	
	func isProper(word: String) -> Bool {
		return word.isBool
	}
	
	func parse(word: String) -> GBError? {
		parser.currentLine.append(.bool(Bool(word)!))
		
		return nil
	}
}

struct NumberParser: WordParser {
	var parser: GBParser
	
	func isProper(word: String) -> Bool {
		return word.isNumber
	}
	
	func parse(word: String) -> GBError? {
		parser.currentLine.append(.number(Float(word)!))
		
		return nil
	}
}

struct PointerParser: WordParser {
	var parser: GBParser
	
	func isProper(word: String) -> Bool {
		return word.isPointer
	}
	
	func parse(word: String) -> GBError? {
		parser.currentLine.append(.pointer(word.replacingOccurrences(of: "$", with: "")))
		
		return nil
	}
}

struct TypeAnnotationParser: WordParser {
	var parser: GBParser
	
	func isProper(word: String) -> Bool {
		return word.isTypeAnnotation
	}
	
	func parse(word: String) -> GBError? {
		parser.currentLine.append(.variable_type(.init(rawValue: word)!))
		
		return nil
	}
}

struct PlainTextParser: WordParser {
	var parser: GBParser
	
	func isProper(word: String) -> Bool {
		return word.isPlainText
	}
	
	func parse(word: String) -> GBError? {
		if !word.isEmpty {
			parser.currentLine.append(.plain_text(word))
		}
		
		return nil
	}
}

struct URLParser: WordParser {
	var parser: GBParser
	
	func isProper(word: String) -> Bool {
		return word.isURL
	}
	
	func parse(word: String) -> GBError? {
		parser.currentLine.append(.url(URL(string: word)!))
		
		return nil
	}
}
