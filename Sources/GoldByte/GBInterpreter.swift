//
//  GBInterpreter.swift
//  GoldByte
//
//  Created by Wiktor Wójcik on 24/11/2021.
//

import Foundation

class GBInterpreter {
	struct Scope: Equatable {
		var id: UUID
		
		init(_ id: UUID) {
			self.id = id
		}
		
		static let global = Scope(UUID())
	}
	
	enum GBTask {
		case macro_execution(String)
		case variable_assignment(String?, GBStorage.ValueType?)
		case if_statement(GBLogicalExpression?, [[GBToken]]?)
		case jump((Int, Int?)?, GBLogicalExpression?)
		case function_definition(GBFunctionDefinition?, [[GBToken]]?)
		case return_value(GBValue?)
	}
	
	var core: GBCore!
	var storage: GBStorage
	var errorHandler: GBErrorHandler
	var console: GBConsole
	var debugger: GBDebugger?
	
	init(_ core: GBCore?, storage: GBStorage, console: GBConsole, errorHandler: GBErrorHandler, debugger: GBDebugger? = nil) {
		self.core = core
		self.errorHandler = errorHandler
		self.storage = storage
		self.console = console
		self.debugger = debugger
	}
	
	func interpret(_ code: [[GBToken]], scope: Scope = .global, isInsideCodeBlock: Bool = false, returnType: GBStorage.ValueType? = nil, continueAt: Int = 0) -> (GBValue?, Int?, GBError?) {
		var lineNumber = continueAt
		let currentScope = scope
		var task: GBTask? = nil
		
		while lineNumber < code.endIndex {
			let line = code[lineNumber]
			
			var arguments: [GBValue] = []
			var key: String? = nil
			
			if let breakpoints = debugger?.breakpoints {
				if breakpoints.contains(lineNumber) && continueAt != lineNumber {
					return (nil, lineNumber, nil)
				}
			}
			
			for (tokenNumber, token) in line.enumerated() {
				if tokenNumber == 0 {
					switch token {
						case .return_keyword:
							task = .return_value(nil)
						case .function_keyword:
							task = .function_definition(nil, nil)
						case .function_invocation(let invocation):
							if line.count == 1 {
								let (function, type, error) = storage.getFunction(invocation.name, arguments: invocation.arguments, line: lineNumber)
								
								if let error = error {
									return (nil, nil, error)
								}
								
								storage.generateVariables(forFunction: invocation.name, withArguments: invocation.arguments, withScope: scope)
								
								let scope = GBStorage.Scope(UUID())
								
								let (returnValue, _, functionError) = interpret(function!, scope: scope, isInsideCodeBlock: true, returnType: type)
								
								if let error = functionError {
									return (nil, nil, error)
								}
								
								storage.deleteScope(scope)
								
								lineNumber += 1
							} else {
								return (nil, nil, .init(type: .interpreting, description: "Line, where function is 1st word, can't contain more instruction", line: lineNumber, word: tokenNumber))
							}
						case .comment:
							lineNumber += 1
							continue
						case .jump_keyword:
							task = .jump(nil, nil)
						case .macro(let key):
							task = .macro_execution(key)
						case .variable_keyword:
							task = .variable_assignment(nil, nil)
						case .if_keyword:
							task = .if_statement(nil, nil)
						case .code_block(let codeBlock):
							if case .function_definition(let definition, let block) = task {
								if block == nil {
									task = .function_definition(definition, codeBlock)
								} else {
									return (nil, nil, .init(type: .interpreting, description: "Too many code blocks for if statement.", line: lineNumber, word: tokenNumber))
								}
							} else if case .if_statement(let condition, let block) = task {
								if block == nil {
									task = .if_statement(condition, codeBlock)
								} else {
									return (nil, nil, .init(type: .interpreting, description: "Too many code blocks for if statement.", line: lineNumber, word: tokenNumber))
								}
							} else {
								return (nil, nil, .init(type: .interpreting, description: "Got code block, even though it's not needed.", line: lineNumber, word: tokenNumber))
							}
						default:
							return (nil, nil, .init(type: .interpreting, description: "Unknown token.", line: lineNumber, word: tokenNumber))
					}
				} else {
					if case .jump(let jumpLineNumber, let condition) = task {
						if jumpLineNumber == nil {
							if case .string(let value) = token {
								if let lineNumber = storage.lineKeys[value] {
									task = .jump(lineNumber, nil)
								} else {
									return (nil, nil, .init(type: .interpreting, description: "No jump key with specified value: \(value).", line: lineNumber, word: tokenNumber))
								}
							} else {
								return (nil, nil, .init(type: .interpreting, description: "Invalid argument type. Expected STRING.", line: lineNumber, word: tokenNumber))
							}
						} else if condition == nil {
							if case .logical_expression(let expression) = token {
								task = .jump(jumpLineNumber, expression)
							} else {
								return (nil, nil, .init(type: .interpreting, description: "Invalid argument type. Expected logical expression.", line: lineNumber, word: tokenNumber))
							}
						} else {
							return (nil, nil, .init(type: .interpreting, description: "Too many arguments for jump. Expected 1 or 2.", line: lineNumber, word: tokenNumber))
						}
					} else if case .function_definition(let definition, let block) = task {
						if definition == nil && block == nil {
							if case .function_definition(let definition) = token {
								task = .function_definition(definition, nil)
							} else {
								return (nil, nil, .init(type: .interpreting, description: "Expected function definition.", line: lineNumber, word: tokenNumber))
							}
						} else {
							return (nil, nil, .init(type: .interpreting, description: "Invalid number of information for function.", line: lineNumber, word: tokenNumber))
						}
					} else if case .variable_assignment(let _, let _) = task {
						if tokenNumber == 1 {
							if case .variable_type(let type) = token {
								task = .variable_assignment(nil, type)
							}
						} else if tokenNumber == 2 {
							if case .plain_text(let value) = token {
								key = value
							} else {
								return (nil, nil, .init(type: .interpreting, description: "Invalid token.", line: lineNumber, word: tokenNumber))
							}
						} else if tokenNumber == 3 {
							if case .variable_assignment(let _, let type) = task {
								if type == nil {
									return (nil, nil, .init(type: .interpreting, description: "Can't recognize type.", line: lineNumber, word: tokenNumber))
								}
							}
							
							if case .string(let value) = token {
								if case .variable_assignment(let _, let type) = task {
									if type != .string {
										return (nil, nil, .init(type: .interpreting, description: "Expected \"\(type!.rawValue)\", got \"string\"", line: lineNumber, word: tokenNumber))
									}
									
									task = .variable_assignment(value.prepare(withStorage: storage), type)
								}
							} else if case .equation(let equation) = token {
								if case .variable_assignment(let _, let type) = task {
									if type != .number {
										return (nil, nil, .init(type: .interpreting, description: "Expected \"\(type!.rawValue)\", got \"number\"", line: lineNumber, word: tokenNumber))
									}
									
									let (result, error) = equation.evaluate()
									
									if let error = error {
										return (nil, nil, error)
									}
									
									task = .variable_assignment(String(result!), type)
								}
							} else if case .number(let value) = token {
								if case .variable_assignment(let _, let type) = task {
									if type != .number {
										return (nil, nil, .init(type: .interpreting, description: "Expected \"\(type!.rawValue)\", got \"number\"", line: lineNumber, word: tokenNumber))
									}
									
									task = .variable_assignment(String(value), type)
								}
							} else if case .logical_expression(let expression) = token {
								if case .variable_assignment(let _, let type) = task {
									if type != .bool {
										return (nil, nil, .init(type: .interpreting, description: "Expected \"\(type!.rawValue)\", got \"bool\"", line: lineNumber, word: tokenNumber))
									}
									
									let (result, error) = expression.evaluate()
									
									if let error = error {
										return (nil, nil, error)
									}
									
									task = .variable_assignment(String(result!), type)
								}
							} else if case .bool(let value) = token {
								if case .variable_assignment(let _, let type) = task {
									if type != .bool {
										return (nil, nil, .init(type: .interpreting, description: "Expected \"\(type!.rawValue)\", got \"bool\"", line: lineNumber, word: tokenNumber))
									}
									
									task = .variable_assignment(String(value), type)
								}
							} else if case .casted(let _, let castingType) = token {
								if case .variable_assignment(let _, let type) = task {
									let (value, error) = token.cast(withStorage: storage)
									
									if let error = error {
										return (nil, nil, error)
									}
									
									if type?.rawValue != castingType.rawValue {
										return (nil, nil, .init(type: .interpreting, description: "Expected \"\(type!.rawValue)\", got \"\(castingType)\"", line: lineNumber, word: tokenNumber))
									}
									
									task = .variable_assignment(value!.getValue(), type)
								}
							} else if case .plain_text(let key) = token {
								if storage.variableExists(key) {
									let variable = storage[key]
									
									if case .variable_assignment(let _, let type) = task {
										if type != variable.type {
											return (nil, nil, .init(type: .interpreting, description: "Expected \"\(type!.rawValue)\", got \"\(variable.type)\"", line: lineNumber, word: tokenNumber))
										}
										
										task = .variable_assignment(String(variable.value), type)
									}
								} else {
									return (nil, nil, .init(type: .interpreting, description: "Uknown token.", line: lineNumber, word: tokenNumber))
								}
							} else {
								return (nil, nil, .init(type: .interpreting, description: "Unknown token.", line: lineNumber, word: tokenNumber))
							}
						} else {
							return (nil, nil, .init(type: .interpreting, description: "Too many values for variable assignment.", line: lineNumber, word: tokenNumber))
						}
					} else if case .return_value(let value) = task {
						if let value = value {
							return (nil, nil, .init(type: .interpreting, description: "RETURN expects 1 or 0 arguments.", line: lineNumber, word: tokenNumber))
						} else {
							if case .string(let value) = token {
								if returnType?.rawValue != GBStorage.ValueType.string.rawValue {
									return (nil, nil, .init(type: .interpreting, description: "Return type of function (\(returnType?.rawValue ?? "VOID")) and returned value (STRING) don't match.", line: lineNumber, word: tokenNumber))
								}
								
								task = .return_value(.string(value.replacingOccurrences(of: "\"", with: "").prepare(withStorage: storage)))
							} else if case .url(let url) = token {
								if returnType?.rawValue != GBStorage.ValueType.url.rawValue {
									return (nil, nil, .init(type: .interpreting, description: "Return type of function (\(returnType?.rawValue ?? "VOID")) and returned value (URL) don't match.", line: lineNumber, word: tokenNumber))
								}
								
								task = .return_value(.url(url))
							} else if case .number(let value) = token {
								if returnType?.rawValue != GBStorage.ValueType.number.rawValue {
									return (nil, nil, .init(type: .interpreting, description: "Return type of function (\(returnType?.rawValue ?? "VOID")) and returned value (NUMBER) don't match.", line: lineNumber, word: tokenNumber))
								}
								
								task = .return_value(.number(value))
							} else if case .plain_text(let key) = token {
								if storage.variableExists(key) {
									let variable = storage[key]
									
									if variable.type == .string {
										if returnType?.rawValue != GBStorage.ValueType.string.rawValue {
											return (nil, nil, .init(type: .interpreting, description: "Return type of function (\(returnType?.rawValue ?? "VOID")) and returned value (STRING) don't match.", line: lineNumber, word: tokenNumber))
										}
										
										task = .return_value(.string(variable.value))
									} else if variable.type == .bool {
										if returnType?.rawValue != GBStorage.ValueType.bool.rawValue {
											return (nil, nil, .init(type: .interpreting, description: "Return type of function (\(returnType?.rawValue ?? "VOID")) and returned value (BOOL) don't match.", line: lineNumber, word: tokenNumber))
										}
										
										task = .return_value(.bool(Bool(variable.value)!))
									} else if variable.type == .number {
										if returnType?.rawValue != GBStorage.ValueType.number.rawValue {
											return (nil, nil, .init(type: .interpreting, description: "Return type of function (\(returnType?.rawValue ?? "VOID")) and returned value (NUMBER) don't match.", line: lineNumber, word: tokenNumber))
										}
										
										task = .return_value(.number(Float(variable.value)!))
									} else if variable.type == .url {
										if returnType?.rawValue != GBStorage.ValueType.url.rawValue {
											return (nil, nil, .init(type: .interpreting, description: "Return type of function (\(returnType?.rawValue ?? "VOID")) and returned value (URL) don't match.", line: lineNumber, word: tokenNumber))
										}
										
										task = .return_value(.url(URL(string: variable.value)!))
									}
								} else {
									return (nil, nil, .init(type: .interpreting, description: "Variable \"\(key)\" doesn't exist.", line: lineNumber, word: tokenNumber))
								}
							} else if case .bool(let value) = token {
								if returnType?.rawValue != GBStorage.ValueType.bool.rawValue {
									return (nil, nil, .init(type: .interpreting, description: "Return type of function (\(returnType?.rawValue ?? "VOID")) and returned value (BOOL) don't match.", line: lineNumber, word: tokenNumber))
								}
								
								task = .return_value(.bool(value))
							} else {
								return (nil, nil, .init(type: .interpreting, description: "RETURN expects a value type.", line: lineNumber, word: tokenNumber))
							}
						}
					} else if case .macro_execution(let _) = task {
						if case .string(let value) = token {
							arguments.append(.string(value.replacingOccurrences(of: "\"", with: "").prepare(withStorage: storage)))
						} else if case .type(let type) = token {
							arguments.append(.string(type.rawValue))
						} else if case .url(let url) = token {
							arguments.append(.url(url))
						} else if case .number(let value) = token {
							arguments.append(.number(value))
						} else if case .casted(let _, let _) = token {
							let (result, error) = token.cast(withStorage: storage)
							
							if let error = error {
								return (nil, nil, error)
							}
							
							arguments.append(result!)
						} else if case .equation(let equation) = token {
							let (result, error) = equation.evaluate()
							
							if let result = result {
								arguments.append(.number(result))
							} else {
								return (nil, nil, error!)
							}
						} else if case .bool(let value) = token {
							arguments.append(.bool(value))
						} else if case .variable_type(let type) = token {
							arguments.append(.string(type.rawValue))
						} else if case .pointer(let value) = token {
							arguments.append(.pointer(value))
						} else if case .function_invocation(let invocation) = token {
							let (function, type, error) = storage.getFunction(invocation.name, arguments: invocation.arguments, line: lineNumber)
							
							if let error = error {
								return (nil, nil, error)
							}
							
							storage.generateVariables(forFunction: invocation.name, withArguments: invocation.arguments, withScope: scope)
							
							let scope = GBStorage.Scope(UUID())
							
							let (returnValue, _, functionError) = interpret(function!, scope: scope, isInsideCodeBlock: true, returnType: type)
							
							if let error = functionError {
								return (nil, nil, error)
							}
							
							if let returnValue = returnValue {
								arguments.append(returnValue)
							} else {
								return (nil, nil, .init(type: .interpreting, description: "Functions used as arguments must return value.", line: lineNumber, word: tokenNumber))
							}
							
							storage.deleteScope(scope)
						} else if case .plain_text(let key) = token {
							if storage.variableExists(key) {
								let variable = storage[key]
								
								if variable.type == .string {
									arguments.append(.string(variable.value))
								} else if variable.type == .bool {
									arguments.append(.bool(Bool(variable.value)!))
								} else if variable.type == .number {
									arguments.append(.number(Float(variable.value)!))
								} else if variable.type == .url {
									arguments.append(.url(URL(string: variable.value)!))
								}
							} else {
								arguments.append(.string(key))
							}
						} else {
							return (nil, nil, .init(type: .interpreting, description: "Invalid argument for macro.", line: lineNumber, word: tokenNumber))
						}
					} else if case .if_statement(let condition, let codeBlock) = task {
						if condition == nil {
							if case .logical_expression(let expression) = token {
								task = .if_statement(expression, nil)
							} else {
								return (nil, nil, .init(type: .interpreting, description: "Invalid token. Expected logical expression.", line: lineNumber, word: tokenNumber))
							}
						} else if codeBlock == nil {
							if case .code_block(let block) = token {
								task = .if_statement(condition, block)
							} else {
								return (nil, nil, .init(type: .interpreting, description: "Invalid token. Expected code block.", line: lineNumber, word: tokenNumber))
							}
						} else {
							return (nil, nil, .init(type: .interpreting, description: "Invalid number of arguments for if statement.", line: lineNumber, word: tokenNumber))
						}
					}
				}
			}
			
			if case .jump(let newLineNumbers, let condition) = task {
				if let newLineNumbers = newLineNumbers, let condition = condition {
					let (result, error) = condition.evaluate()
					
					if let error = error {
						return (nil, nil, error)
					}

					if let result = result {
						if result {
							if let codeBlockNewLineNumber = newLineNumbers.1 {
								lineNumber = codeBlockNewLineNumber
								task = nil
								continue
							} else {
								if isInsideCodeBlock {
									return (nil, newLineNumbers.0, nil)
								} else {
									lineNumber = newLineNumbers.0
									task = nil
									continue
								}
							}
						}
					}
				} else if let newLineNumbers = newLineNumbers {
					if let codeBlockNewLineNumber = newLineNumbers.1 {
						lineNumber = codeBlockNewLineNumber
						task = nil
						continue
					} else {
						if isInsideCodeBlock {
							return (nil, newLineNumbers.0, nil)
						} else {
							lineNumber = newLineNumbers.0
							task = nil
							continue
						}
					}
				} else {
					return (nil, nil, .init(type: .interpreting, description: "No jump key specified for jump operation and/or condition.", line: lineNumber, word: 0))
				}
			} else if case .macro_execution(let key) = task {
				if let error = storage.handleMacro(key, arguments: arguments, line: lineNumber) {
					return (nil, nil, error)
				}
				
				task = nil
				lineNumber += 1
			} else if case .variable_assignment(let value, let type) = task {
				guard let key = key, let value = value, let type = type else {
					return (nil, nil, .init(type: .interpreting, description: "Not enough arguments for variable assignment.", line: lineNumber, word: 0))
				}
				
				storage[key] = .init(value: value, type: type, scope: currentScope)
				
				task = nil
				lineNumber += 1
			} else if case .if_statement(let condition, let block) = task {
				guard let condition = condition, let block = block else {
					lineNumber += 1
					continue
				}
				
				let (result, error) = condition.evaluate()
				
				if let error = error {
					return (nil, nil, error)
				}
				
				if let result = result {
					if result {
						let (_, newLine, error) = interpret(block, isInsideCodeBlock: true)
						
						if let error = error {
							return (nil, nil, error)
						}
						
						if let newLine = newLine {
							lineNumber = newLine
							task = nil
							continue
						}
					}
				}
				
				task = nil
				lineNumber += 1
			} else if case .function_definition(let definition, let block) = task {
				guard let definition = definition, let block = block else {
					lineNumber += 1
					continue
				}
				
				storage.saveFunction(definition, codeBlock: block)
				
				task = nil
				lineNumber += 1
			} else if case .return_value(let value) = task {
				if value == nil && returnType == nil {
					return (nil, nil, nil)
				} else if value == nil || returnType == nil {
					return (nil, nil, .init(type: .interpreting, description: "Return values and expected function return type don't match.", line: lineNumber, word: 0))
				}
				
				return (value, nil, nil)
			}
		}
		
		if returnType != nil {
			return (nil, nil, .init(type: .interpreting, description: "Expected value from function."))
		}
		
		return (nil, nil, nil)
	}
}
