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
		case constant_assignment(String?, GBStorage.ValueType?)
		case if_statement(GBLogicalExpression?, [[GBToken]]?)
		case while_statement(GBLogicalExpression?, [[GBToken]]?)
		case function_definition(GBFunctionDefinition?, [[GBToken]]?)
		case return_value(GBValue?)
		case namespace(String?, [[GBToken]]?)
		case structure(String?, [[GBToken]]?)
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
	
	func interpret(_ code: [[GBToken]], scope: Scope = .global, isInsideCodeBlock: Bool = false, returnType: GBStorage.ValueType? = nil, continueAt: Int = 0, namespace: String? = nil, isFunction: Bool = false, lostLineNumbers: Int = 0) -> (GBValue?, Int, GBError?) {
		let namespace = namespace ?? ""
		let currentScope = scope
		var task: GBTask? = nil
		
		var globalVariable = false
		for (lineNumber, line) in code.enumerated() {
			let lineNumber = lineNumber + lostLineNumbers
			var arguments: [GBValue] = []
			var key: String? = nil
			
			for (tokenNumber, token) in line.enumerated() {
				if tokenNumber == 0 {
					switch token {
						case .namespace_keyword:
							task = .namespace(nil, nil)
						case .exit_keyword:
							return (nil, 0, nil)
						case .return_keyword:
							task = .return_value(nil)
						case .function_keyword:
							task = .function_definition(nil, nil)
						case .function_invocation(let invocation):
							var arguments = [GBFunctionArgument]()
							
							for argument in invocation.arguments {
								if argument.type == .variable {
									if storage.variableExists(argument.value) {
										let variable = storage[argument.value]
										arguments.append(.init(value: variable.value, type: variable.type))
									} else {
										return (nil, 1, .init(type: .panic, description: "Variable \"\(argument.value)\" doesn't exist.", line: lineNumber, word: tokenNumber))
									}
								} else {
									arguments.append(argument)
								}
							}

							if line.count == 1 {
								let (function, type, error) = storage.getFunction(invocation.name, arguments: arguments, line: lineNumber)
								
								if let error = error {
									return (nil, 1, error)
								}
								
								let scope = GBStorage.Scope(UUID())
								
								storage.generateVariables(forFunction: invocation.name, withArguments: arguments, withScope: scope)
								
								let (_, _, functionError) = interpret(function!, scope: scope, isInsideCodeBlock: true, returnType: type, namespace: invocation.name.components(separatedBy: "::").dropLast().joined(separator: "::") + "::", isFunction: true, lostLineNumbers: lineNumber)
								
								if let error = functionError {
									return (nil, 1, error)
								}
								
								storage.deleteScope(scope)
							} else {
								return (nil, 1, .init(type: .panic, description: "Line, where function is 1st word, can't contain more instruction", line: lineNumber, word: tokenNumber))
							}
						case .macro(let key):
							task = .macro_execution(key)
						case .variable_keyword:
							task = .variable_assignment(nil, nil)
						case .constant_keyword:
							task = .constant_assignment(nil, nil)
						case .if_keyword:
							task = .if_statement(nil, nil)
						case .struct_keyword:
							task = .structure(nil, nil)
						case .while_keyword:
							task = .while_statement(nil, nil)
						case .code_block(let codeBlock):
							if case .namespace(let name, let block) = task {
								if block == nil {
									task = .namespace(name, codeBlock)
								} else {
									return (nil, 1, .init(type: .panic, description: "Too many code blocks for namespace.", line: lineNumber, word: tokenNumber))
								}
							} else if case .structure(let name, let block) = task {
								if block == nil {
									task = .structure(name, codeBlock)
								} else {
									return (nil, 1, .init(type: .panic, description: "Too many code blocks for structure.", line: lineNumber, word: tokenNumber))
								}
							} else if case .function_definition(let definition, let block) = task {
								if block == nil {
									task = .function_definition(definition, codeBlock)
								} else {
									return (nil, 1, .init(type: .panic, description: "Too many code blocks for function.", line: lineNumber, word: tokenNumber))
								}
							} else if case .while_statement(let condition, let block) = task {
								if block == nil {
									task = .while_statement(condition, codeBlock)
								} else {
									return (nil, 1, .init(type: .panic, description: "Too many code blocks for while statement.", line: lineNumber, word: tokenNumber))
								}
							} else if case .if_statement(let condition, let block) = task {
								if block == nil {
									task = .if_statement(condition, codeBlock)
								} else {
									return (nil, 1, .init(type: .panic, description: "Too many code blocks for if statement.", line: lineNumber, word: tokenNumber))
								}
							} else {
								return (nil, 1, .init(type: .panic, description: "Got code block, even though it's not needed.", line: lineNumber, word: tokenNumber))
							}
						default:
							return (nil, 1, .init(type: .panic, description: "Unknown token.", line: lineNumber, word: tokenNumber))
					}
				} else {
					if case .function_definition(let definition, let block) = task {
						if definition == nil && block == nil {
							if case .function_definition(let definition) = token {
								task = .function_definition(definition, nil)
							} else {
								return (nil, 1, .init(type: .panic, description: "Expected function definition.", line: lineNumber, word: tokenNumber))
							}
						} else {
							return (nil, 1, .init(type: .panic, description: "Invalid number of information for function.", line: lineNumber, word: tokenNumber))
						}
					} else if case .variable_assignment( _, let _) = task {
						if tokenNumber == 1 {
							if case .variable_type(let type) = token {
								task = .variable_assignment(nil, type)
							}
						} else if tokenNumber == 2 {
							if case .plain_text(let value) = token {
								key = value
							} else {
								return (nil, 1, .init(type: .panic, description: "Invalid token.", line: lineNumber, word: tokenNumber))
							}
						} else if tokenNumber == 3 {
							if case .variable_assignment( _, let type) = task {
								if type == nil {
									return (nil, 1, .init(type: .panic, description: "Can't recognize type.", line: lineNumber, word: tokenNumber))
								}
							}
							
							if case .string(let value) = token {
								if case .variable_assignment( _, let type) = task {
									if type != .string {
										return (nil, 1, .init(type: .panic, description: "Expected \"\(type!.rawValue)\", got \"string\"", line: lineNumber, word: tokenNumber))
									}
									
									task = .variable_assignment(value.prepare(withStorage: storage, inNamespace: namespace), type)
								}
							} else if case .equation(let equation) = token {
								if case .variable_assignment( _, let type) = task {
									if type != .number {
										return (nil, 1, .init(type: .panic, description: "Expected \"\(type!.rawValue)\", got \"number\"", line: lineNumber, word: tokenNumber))
									}
									
									let (result, error) = equation.evaluate()
									
									if let error = error {
										return (nil, 1, error)
									}
									
									task = .variable_assignment(String(result!), type)
								}
							} else if case .function_invocation(let invocation) = token {
								if case .variable_assignment( _, _) = task {
									var arguments = [GBFunctionArgument]()
									
									for argument in invocation.arguments {
										if argument.type == .variable {
											if storage.variableExists(argument.value) {
												let variable = storage[argument.value]
												arguments.append(.init(value: variable.value, type: variable.type))
											} else {
												return (nil, 1, .init(type: .panic, description: "Variable \"\(argument.value)\" doesn't exist.", line: lineNumber, word: tokenNumber))
											}
										} else {
											arguments.append(argument)
										}
									}
									
									let (function, type, error) = storage.getFunction(invocation.name, arguments: arguments, line: lineNumber)
										
									if let error = error {
										return (nil, 1, error)
									}
										
									let scope = GBStorage.Scope(UUID())
										
									storage.generateVariables(forFunction: invocation.name, withArguments: arguments, withScope: scope)
										
									let (result, _, functionError) = interpret(function!, scope: scope, isInsideCodeBlock: true, returnType: type, namespace: invocation.name.components(separatedBy: "::").dropLast().joined(separator: "::") + "::", isFunction: true, lostLineNumbers: lineNumber)
										
									if let error = functionError {
										return (nil, 1, error)
									}
										
									storage.deleteScope(scope)
									
									
									if let error = error {
										return (nil, 1, error)
									}
									
									if case .number(let value) = result!, type == .number {
										task = .variable_assignment(String(value), type)
									} else if case .bool(let value) = result!, type == .bool {
										task = .variable_assignment(String(value), type)
									} else if case .string(let value) = result!, type == .string {
										task = .variable_assignment(String(value), type)
									} else {
										return (nil, 1, .init(type: .panic, description: "Functions return value is not the same as variable type.", line: lineNumber, word: tokenNumber))
									}
								}
							} else if case .number(let value) = token {
								if case .variable_assignment( _, let type) = task {
									if type != .number {
										return (nil, 1, .init(type: .panic, description: "Expected \"\(type!.rawValue)\", got \"number\"", line: lineNumber, word: tokenNumber))
									}
									
									task = .variable_assignment(String(value), type)
								}
							} else if case .logical_expression(let expression) = token {
								if case .variable_assignment( _, let type) = task {
									if type != .bool {
										return (nil, 1, .init(type: .panic, description: "Expected \"\(type!.rawValue)\", got \"bool\"", line: lineNumber, word: tokenNumber))
									}
									
									let (result, error) = expression.evaluate()
									
									if let error = error {
										return (nil, 1, error)
									}
									
									task = .variable_assignment(String(result!), type)
								}
							} else if case .bool(let value) = token {
								if case .variable_assignment( _, let type) = task {
									if type != .bool {
										return (nil, 1, .init(type: .panic, description: "Expected \"\(type!.rawValue)\", got \"bool\"", line: lineNumber, word: tokenNumber))
									}
									
									task = .variable_assignment(String(value), type)
								}
							} else if case .casted( _, let castingType) = token {
								if case .variable_assignment( _, let type) = task {
									let (value, error) = token.cast(withStorage: storage)
									
									if let error = error {
										return (nil, 1, error)
									}
									
									if type?.rawValue != castingType.rawValue {
										return (nil, 1, .init(type: .panic, description: "Expected \"\(type!.rawValue)\", got \"\(castingType)\"", line: lineNumber, word: tokenNumber))
									}
									
									task = .variable_assignment(value!.getValue(), type)
								}
							} else if case .plain_text(let key) = token {
								var namespaces = key.components(separatedBy: "::")
								var key = namespaces.removeLast()
								
								if namespaces.count != 0 && namespaces[0] == "self" {
									namespaces.removeFirst()
									namespaces.insert(contentsOf: namespace.components(separatedBy: "::"), at: 0)
								}
								
								let seperator = namespaces.joined(separator: "::").isEmpty ? "" : "::"
								
								key = namespaces.joined(separator: "::") + seperator + key
								
								if storage.variableExists(key) {
									let variable = storage[key]
									
									if case .variable_assignment( _, let type) = task {
										if type != variable.type {
											return (nil, 1, .init(type: .panic, description: "Expected \"\(type!.rawValue)\", got \"\(variable.type)\"", line: lineNumber, word: tokenNumber))
										}
										
										task = .variable_assignment(String(variable.value), type)
									}
								} else {
									return (nil, 1, .init(type: .panic, description: "Uknown token.", line: lineNumber, word: tokenNumber))
								}
							} else {
								return (nil, 1, .init(type: .panic, description: "Unknown token.", line: lineNumber, word: tokenNumber))
							}
						} else if tokenNumber == 4 {
							if case .bool(let value) = token {
								globalVariable = value
							} else {
								return (nil, 1, .init(type: .panic, description: "Invalid token: \(token).", line: lineNumber, word: tokenNumber))
							}
						} else {
							return (nil, 1, .init(type: .panic, description: "Too many values for variable assignment.", line: lineNumber, word: tokenNumber))
						}
					} else if case .constant_assignment( _, let _) = task {
						if tokenNumber == 1 {
							if case .variable_type(let type) = token {
								task = .constant_assignment(nil, type)
							}
						} else if tokenNumber == 2 {
							if case .plain_text(let value) = token {
								key = value
							} else {
								return (nil, 1, .init(type: .panic, description: "Invalid token.", line: lineNumber, word: tokenNumber))
							}
						} else if tokenNumber == 3 {
							if case .constant_assignment( _, let type) = task {
								if type == nil {
									return (nil, 1, .init(type: .panic, description: "Can't recognize type.", line: lineNumber, word: tokenNumber))
								}
							}
							
							if case .string(let value) = token {
								if case .constant_assignment( _, let type) = task {
									if type != .string {
										return (nil, 1, .init(type: .panic, description: "Expected \"\(type!.rawValue)\", got \"string\"", line: lineNumber, word: tokenNumber))
									}
									
									task = .constant_assignment(value.prepare(withStorage: storage, inNamespace: namespace), type)
								}
							} else if case .equation(let equation) = token {
								if case .constant_assignment( _, let type) = task {
									if type != .number {
										return (nil, 1, .init(type: .panic, description: "Expected \"\(type!.rawValue)\", got \"number\"", line: lineNumber, word: tokenNumber))
									}
									
									let (result, error) = equation.evaluate()
									
									if let error = error {
										return (nil, 1, error)
									}
									
									task = .constant_assignment(String(result!), type)
								}
							} else if case .function_invocation(let invocation) = token {
								if case .variable_assignment( _, let type) = task {
									if type != .number {
										return (nil, 1, .init(type: .panic, description: "Expected \"\(type!.rawValue)\", got \"number\"", line: lineNumber, word: tokenNumber))
									}
									
									var arguments = [GBFunctionArgument]()
									
									for argument in invocation.arguments {
										if argument.type == .variable {
											if storage.variableExists(argument.value) {
												let variable = storage[argument.value]
												arguments.append(.init(value: variable.value, type: variable.type))
											} else {
												return (nil, 1, .init(type: .panic, description: "Variable \"\(argument.value)\" doesn't exist.", line: lineNumber, word: tokenNumber))
											}
										} else {
											arguments.append(argument)
										}
									}
									
									let (function, type, error) = storage.getFunction(invocation.name, arguments: arguments, line: lineNumber)
									
									if let error = error {
										return (nil, 1, error)
									}
									
									let scope = GBStorage.Scope(UUID())
									
									storage.generateVariables(forFunction: invocation.name, withArguments: arguments, withScope: scope)
									
									let (result, _, functionError) = interpret(function!, scope: scope, isInsideCodeBlock: true, returnType: type, namespace: invocation.name.components(separatedBy: "::").dropLast().joined(separator: "::") + "::", isFunction: true, lostLineNumbers: lineNumber)
									
									if let error = functionError {
										return (nil, 1, error)
									}
									
									storage.deleteScope(scope)
									
									
									if let error = error {
										return (nil, 1, error)
									}
									
									if case .number(let value) = result!, type == .number {
										task = .variable_assignment(String(value), type)
									} else if case .bool(let value) = result!, type == .bool {
										task = .variable_assignment(String(value), type)
									} else if case .string(let value) = result!, type == .string {
										task = .variable_assignment(String(value), type)
									} else {
										return (nil, 1, .init(type: .panic, description: "Functions return value is not the same as variable type.", line: lineNumber, word: tokenNumber))
									}
								}
							} else if case .number(let value) = token {
								if case .constant_assignment( _, let type) = task {
									if type != .number {
										return (nil, 1, .init(type: .panic, description: "Expected \"\(type!.rawValue)\", got \"number\"", line: lineNumber, word: tokenNumber))
									}
									
									task = .variable_assignment(String(value), type)
								}
							} else if case .logical_expression(let expression) = token {
								if case .constant_assignment( _, let type) = task {
									if type != .bool {
										return (nil, 1, .init(type: .panic, description: "Expected \"\(type!.rawValue)\", got \"bool\"", line: lineNumber, word: tokenNumber))
									}
									
									let (result, error) = expression.evaluate()
									
									if let error = error {
										return (nil, 1, error)
									}
									
									task = .variable_assignment(String(result!), type)
								}
							} else if case .bool(let value) = token {
								if case .constant_assignment( _, let type) = task {
									if type != .bool {
										return (nil, 1, .init(type: .panic, description: "Expected \"\(type!.rawValue)\", got \"bool\"", line: lineNumber, word: tokenNumber))
									}
									
									task = .variable_assignment(String(value), type)
								}
							} else if case .casted( _, let castingType) = token {
								if case .constant_assignment( _, let type) = task {
									let (value, error) = token.cast(withStorage: storage)
									
									if let error = error {
										return (nil, 1, error)
									}
									
									if type?.rawValue != castingType.rawValue {
										return (nil, 1, .init(type: .panic, description: "Expected \"\(type!.rawValue)\", got \"\(castingType)\"", line: lineNumber, word: tokenNumber))
									}
									
									task = .constant_assignment(value!.getValue(), type)
								}
							} else if case .plain_text(let key) = token {
								var namespaces = key.components(separatedBy: "::")
								var key = namespaces.removeLast()
								
								if namespaces.count != 0 && namespaces[0] == "self" {
									namespaces.removeFirst()
									namespaces.insert(contentsOf: namespace.components(separatedBy: "::"), at: 0)
								}
								
								let seperator = namespaces.joined(separator: "::").isEmpty ? "" : "::"
								
								key = namespaces.joined(separator: "::") + seperator + key
								
								if storage.variableExists(key) {
									let variable = storage[key]
									
									if case .variable_assignment( _, let type) = task {
										if type != variable.type {
											return (nil, 1, .init(type: .panic, description: "Expected \"\(type!.rawValue)\", got \"\(variable.type)\"", line: lineNumber, word: tokenNumber))
										}
										
										task = .constant_assignment(String(variable.value), type)
									}
								} else {
									return (nil, 1, .init(type: .panic, description: "Uknown token.", line: lineNumber, word: tokenNumber))
								}
							} else {
								return (nil, 1, .init(type: .panic, description: "Unknown token.", line: lineNumber, word: tokenNumber))
							}
						} else if tokenNumber == 4 {
							if case .bool(let value) = token {
								globalVariable = value
							} else {
								return (nil, 1, .init(type: .panic, description: "Invalid token: \(token).", line: lineNumber, word: tokenNumber))
							}
						} else {
							return (nil, 1, .init(type: .panic, description: "Too many values for constant assignment.", line: lineNumber, word: tokenNumber))
						}
					} else if case .return_value(let value) = task {
						if value != nil {
							return (nil, 1, .init(type: .panic, description: "return expects 1 or 0 arguments.", line: lineNumber, word: tokenNumber))
						} else {
							if case .string(let value) = token {
								if returnType?.rawValue != GBStorage.ValueType.string.rawValue {
									return (nil, 1, .init(type: .panic, description: "Return type of function (\(returnType?.rawValue ?? "VOID")) and returned value (STRING) don't match.", line: lineNumber, word: tokenNumber))
								}
								
								task = .return_value(.string(value.replacingOccurrences(of: "\"", with: "").prepare(withStorage: storage, inNamespace: namespace)))
							} else if case .url(let url) = token {
								if returnType?.rawValue != GBStorage.ValueType.url.rawValue {
									return (nil, 1, .init(type: .panic, description: "Return type of function (\(returnType?.rawValue ?? "VOID")) and returned value (URL) don't match.", line: lineNumber, word: tokenNumber))
								}
								
								task = .return_value(.url(url))
							} else if case .number(let value) = token {
								if returnType?.rawValue != GBStorage.ValueType.number.rawValue {
									return (nil, 1, .init(type: .panic, description: "Return type of function (\(returnType?.rawValue ?? "VOID")) and returned value (NUMBER) don't match.", line: lineNumber, word: tokenNumber))
								}
								
								task = .return_value(.number(value))
							} else if case .plain_text(let key) = token {
								var namespaces = key.components(separatedBy: "::")
								var key = namespaces.removeLast()
								
								if namespaces.count != 0 && namespaces[0] == "self" {
									namespaces.removeFirst()
									namespaces.insert(contentsOf: namespace.components(separatedBy: "::"), at: 0)
								}
								
								let seperator = namespaces.joined(separator: "::").isEmpty ? "" : "::"
								
								key = namespaces.joined(separator: "::") + seperator + key
								
								if storage.variableExists(key) {
									let variable = storage[key]
									
									if variable.type == .string {
										if returnType?.rawValue != GBStorage.ValueType.string.rawValue {
											return (nil, 1, .init(type: .panic, description: "Return type of function (\(returnType?.rawValue ?? "VOID")) and returned value (STRING) don't match.", line: lineNumber, word: tokenNumber))
										}
										
										task = .return_value(.string(variable.value))
									} else if variable.type == .bool {
										if returnType?.rawValue != GBStorage.ValueType.bool.rawValue {
											return (nil, 1, .init(type: .panic, description: "Return type of function (\(returnType?.rawValue ?? "VOID")) and returned value (BOOL) don't match.", line: lineNumber, word: tokenNumber))
										}
										
										task = .return_value(.bool(Bool(variable.value)!))
									} else if variable.type == .number {
										if returnType?.rawValue != GBStorage.ValueType.number.rawValue {
											return (nil, 1, .init(type: .panic, description: "Return type of function (\(returnType?.rawValue ?? "VOID")) and returned value (NUMBER) don't match.", line: lineNumber, word: tokenNumber))
										}
										
										task = .return_value(.number(Float(variable.value)!))
									} else if variable.type == .url {
										if returnType?.rawValue != GBStorage.ValueType.url.rawValue {
											return (nil, 1, .init(type: .panic, description: "Return type of function (\(returnType?.rawValue ?? "VOID")) and returned value (URL) don't match.", line: lineNumber, word: tokenNumber))
										}
										
										task = .return_value(.url(URL(string: variable.value)!))
									}
								} else {
									return (nil, 1, .init(type: .panic, description: "Variable \"\(key)\" doesn't exist.", line: lineNumber, word: tokenNumber))
								}
							} else if case .bool(let value) = token {
								if returnType?.rawValue != GBStorage.ValueType.bool.rawValue {
									return (nil, 1, .init(type: .panic, description: "Return type of function (\(returnType?.rawValue ?? "VOID")) and returned value (BOOL) don't match.", line: lineNumber, word: tokenNumber))
								}
								
								task = .return_value(.bool(value))
							} else {
								return (nil, 1, .init(type: .panic, description: "return expects a value type.", line: lineNumber, word: tokenNumber))
							}
						}
					} else if case .macro_execution( _) = task {
						if case .string(let value) = token {
							arguments.append(.string(value.prepare(withStorage: storage, inNamespace: namespace)))
						} else if case .type(let type) = token {
							arguments.append(.string(type.rawValue))
						} else if case .url(let url) = token {
							arguments.append(.url(url))
						} else if case .number(let value) = token {
							arguments.append(.number(value))
						} else if case .casted( _, let _) = token {
							let (result, error) = token.cast(withStorage: storage)
							
							if let error = error {
								return (nil, 1, error)
							}
							
							arguments.append(result!)
						} else if case .equation(let equation) = token {
							let (result, error) = equation.evaluate()
							
							if let result = result {
								arguments.append(.number(result))
							} else {
								return (nil, 1, error!)
							}
						} else if case .bool(let value) = token {
							arguments.append(.bool(value))
						} else if case .variable_type(let type) = token {
							arguments.append(.string(type.rawValue))
						} else if case .pointer(let value) = token {
							var namespaces = value.components(separatedBy: "::")
							var name = namespaces.removeLast()
							
							if namespaces.count != 0 && namespaces[0] == "self" {
								namespaces.removeFirst()
								namespaces.insert(contentsOf: namespace.components(separatedBy: "::"), at: 0)
							}
							
							var seperator = ""
							
							if !namespaces.joined(separator: "::").isEmpty {
								seperator = "::"
							}
							
							name = namespaces.joined(separator: "::") + seperator + name
							
							arguments.append(.pointer(name))
						} else if case .function_invocation(let invocation) = token {
							var functionArguments = [GBFunctionArgument]()
							
							for argument in invocation.arguments {
								if argument.type == .variable {
									if storage.variableExists(argument.value) {
										let variable = storage[argument.value]
										functionArguments.append(.init(value: variable.value, type: variable.type))
									} else {
										return (nil, 1, .init(type: .panic, description: "Variable \"\(argument.value)\" doesn't exist.", line: lineNumber, word: tokenNumber))
									}
								} else {
									functionArguments.append(argument)
								}
							}
							
							let (function, type, error) = storage.getFunction(invocation.name, arguments: functionArguments, line: lineNumber)
							
							if let error = error {
								return (nil, 1, error)
							}
							
							storage.generateVariables(forFunction: invocation.name, withArguments: functionArguments, withScope: scope)
							
							let scope = GBStorage.Scope(UUID())

							let (returnValue, _, functionError) = interpret(function!, scope: scope, isInsideCodeBlock: true, returnType: type, namespace: invocation.name.components(separatedBy: "::").dropLast().joined(separator: "::") + "::", isFunction: true, lostLineNumbers: lineNumber)
							
							if let error = functionError {
								return (nil, 1, error)
							}
							
							if let returnValue = returnValue {
								arguments.append(returnValue)
							} else {
								return (nil, 1, .init(type: .panic, description: "Functions used as arguments must return value.", line: lineNumber, word: tokenNumber))
							}
							
							storage.deleteScope(scope)
						} else if case .plain_text(let key) = token {
							var namespaces = key.components(separatedBy: "::")
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
							
							if storage.structs[key] != nil {
								arguments.append(.string(key))
							} else if storage.variableExists(key) {
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
								return (nil, 1, .init(type: .panic, description: "Variable \"\(key)\" doesn't exist.", line: lineNumber, word: tokenNumber))
							}
						} else {
							return (nil, 1, .init(type: .panic, description: "Invalid argument for macro.", line: lineNumber, word: tokenNumber))
						}
					} else if case .namespace(let name, let codeBlock) = task {
						if name == nil {
							if case .plain_text(let value) = token {
								task = .namespace(value, nil)
							} else {
								return (nil, 1, .init(type: .panic, description: "Invalid token. Expected plain text.", line: lineNumber, word: tokenNumber))
							}
						} else if codeBlock == nil {
							if case .code_block(let block) = token {
								task = .namespace(name, block)
							} else {
								return (nil, 1, .init(type: .panic, description: "Invalid token. Expected code block.", line: lineNumber, word: tokenNumber))
							}
						} else {
							return (nil, 1, .init(type: .panic, description: "Invalid number of arguments for namespace.", line: lineNumber, word: tokenNumber))
						}
					} else if case .structure(let name, let codeBlock) = task {
						if name == nil {
							if case .plain_text(let value) = token {
								task = .structure(value, nil)
							} else {
								return (nil, 1, .init(type: .panic, description: "Invalid token. Expected plain text.", line: lineNumber, word: tokenNumber))
							}
						} else if codeBlock == nil {
							if case .code_block(let block) = token {
								task = .structure(name, block)
							} else {
								return (nil, 1, .init(type: .panic, description: "Invalid token. Expected code block.", line: lineNumber, word: tokenNumber))
							}
						} else {
							return (nil, 1, .init(type: .panic, description: "Invalid number of arguments for structure.", line: lineNumber, word: tokenNumber))
						}
					} else if case .if_statement(let condition, let codeBlock) = task {
						if condition == nil {
							if case .logical_expression(let expression) = token {
								task = .if_statement(expression, nil)
							} else {
								return (nil, 1, .init(type: .panic, description: "Invalid token. Expected logical expression.", line: lineNumber, word: tokenNumber))
							}
						} else if codeBlock == nil {
							if case .code_block(let block) = token {
								task = .if_statement(condition, block)
							} else {
								return (nil, 1, .init(type: .panic, description: "Invalid token. Expected code block.", line: lineNumber, word: tokenNumber))
							}
						} else {
							return (nil, 1, .init(type: .panic, description: "Invalid number of arguments for if statement.", line: lineNumber, word: tokenNumber))
						}
					} else if case .while_statement(let condition, let codeBlock) = task {
						if condition == nil {
							if case .logical_expression(let expression) = token {
								task = .while_statement(expression, nil)
							} else {
								return (nil, 1, .init(type: .panic, description: "Invalid token. Expected logical expression.", line: lineNumber, word: tokenNumber))
							}
						} else if codeBlock == nil {
							if case .code_block(let block) = token {
								task = .while_statement(condition, block)
							} else {
								return (nil, 1, .init(type: .panic, description: "Invalid token. Expected code block.", line: lineNumber, word: tokenNumber))
							}
						} else {
							return (nil, 1, .init(type: .panic, description: "Invalid number of arguments for while statement.", line: lineNumber, word: tokenNumber))
						}
					}
				}
			}
			
			if case .macro_execution(let key) = task {
				if let error = storage.handleMacro(key, arguments: arguments, line: lineNumber, namespace: namespace) {
					var error = error
					
					error.description = key + ": " + error.description
					
					return (nil, 1, error)
				}
				
				task = nil
			} else if case .variable_assignment(let value, let type) = task {
				guard let key = key, let value = value, let type = type else {
					return (nil, 1, .init(type: .panic, description: "Not enough arguments for variable assignment.", line: lineNumber, word: 0))
				}
				
				var keyWithNamespace = key
				
				if namespace != "" && !isFunction {
					keyWithNamespace = namespace + "::" + key
				}
				
				if globalVariable {
					storage[keyWithNamespace] = .init(value: value, type: type, scope: .global)
				} else {
					storage[keyWithNamespace] = .init(value: value, type: type, scope: currentScope)
				}
				
				globalVariable = false
				task = nil
			} else if case .constant_assignment(let value, let type) = task {
				guard let key = key, let value = value, let type = type else {
					return (nil, 1, .init(type: .panic, description: "Not enough arguments for variable assignment.", line: lineNumber, word: 0))
				}
				
				var keyWithNamespace = key
				
				if namespace != "" && !isFunction {
					keyWithNamespace = namespace + "::" + key
				}
				
				if globalVariable {
					storage[keyWithNamespace] = .init(value: value, type: type, scope: .global, isConstant: true)
				} else {
					storage[keyWithNamespace] = .init(value: value, type: type, scope: currentScope, isConstant: true)
				}
				
				globalVariable = false
				task = nil
			} else if case .namespace(let name, let block) = task {
				guard let name = name, let block = block else {
					continue
				}
				
				if namespace == "" {
					let (_, exitCode, error) = interpret(block, isInsideCodeBlock: true, namespace: name, lostLineNumbers: lineNumber)
					
					if let error = error {
						return (nil, exitCode, error)
					}
				} else {
					let (_, exitCode, error) = interpret(block, isInsideCodeBlock: true, namespace: namespace + "::" + name, lostLineNumbers: lineNumber)
					
					if let error = error {
						return (nil, exitCode, error)
					}
				}
				
				task = nil
			} else if case .structure(let name, let block) = task {
				guard let name = name, let block = block else {
					continue
				}
				
				if namespace == "" {
					storage.structs[name] = block
				} else {
					storage.structs[namespace + "::" + name] = block
				}
				
				task = nil
			} else if case .if_statement(let condition, let block) = task {
				guard let condition = condition, let block = block else {
					continue
				}
				
				let (result, error) = condition.evaluate()
				
				if let error = error {
					return (nil, 1, error)
				}
				
				if let result = result {
					if result {
						let (returnValue, exitCode, error) = interpret(block, isInsideCodeBlock: true, returnType: returnType, lostLineNumbers: lineNumber)
						
						if let error = error {
							return (nil, exitCode, error)
						}
						
						if returnValue != nil {
							return (returnValue, 0, nil)
						}
					}
				}
				
				task = nil
			} else if case .while_statement(let condition, let block) = task {
				guard let condition = condition, let block = block else {
					continue
				}
				
				var conditionResult = true
				
				while conditionResult {
					let (result, error) = condition.evaluate()
					
					if let error = error {
						return (nil, 1, error)
					}
					
					if let result = result {
						conditionResult = result
						
						if result {
							let (returnValue, exitCode, error) = interpret(block, isInsideCodeBlock: true, returnType: returnType, lostLineNumbers: lineNumber)
							
							if let error = error {
								return (nil, exitCode, error)
							}
							
							if returnValue != nil {
								return (returnValue, 0, nil)
							}
						}
					}
				}
				
				task = nil
			} else if case .function_definition(let definition, let block) = task {
				guard let definition = definition, let block = block else {
					continue
				}
				
				var definitionWithNamespace = definition
				
				if namespace != "" {
					definitionWithNamespace.name = namespace + "::" + definition.name
				}

				storage.saveFunction(definitionWithNamespace, codeBlock: block)
				
				task = nil
			} else if case .return_value(let value) = task {
				if value == nil && returnType == nil {
					return (nil, 0, nil)
				} else if value == nil || returnType == nil {
					return (nil, 1, .init(type: .panic, description: "Return values and expected function return type don't match.", line: lineNumber, word: 0))
				}
				
				return (value, 0, nil)
			}
		}
		
		if isFunction {
			if returnType != nil && returnType != .void {
				return (nil, 1, .init(type: .panic, description: "Expected value from function."))
			}
		}
		
		return (nil, 0, nil)
	}
}
