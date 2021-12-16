//
//  Defaults.swift
//  GoldByte
//
//  Created by Wiktor Wójcik on 24/11/2021.
//

import Foundation

extension GBCore {
	func getMacros(withStorage storage: GBStorage) -> [String: GBMacroAction] {
		GBStorage.buildMacros {
			GBMacro("NEW") { arguments, line in
				if arguments.count != 2 {
					return .init(type: .macro, description: "Expected 2 arguments, got \(arguments.count).", line: line, word: 0)
				}
				
				var structureNamespace = ""
				var structureCode = [[GBToken]]()
				var instanceName = ""
				
				if case .string(let id) = arguments[0] {
					var namespaces = id.components(separatedBy: "::")
					var name = namespaces.removeLast()
					
					namespaces = namespaces.map { "[\($0)]" }
					
					name = namespaces.joined(separator: "") + name
					
					if storage.structs[name] != nil {
						structureCode = storage.structs[name]!
						structureNamespace = namespaces.joined(separator: "")
					} else {
						return .init(type: .macro, description: "Structure with name \"\(id)\" doesn't exist.", line: line, word: 1)
					}
				} else {
					return .init(type: .macro, description: "Expected value of type STRING or plain text.", line: line, word: 1)
				}
				
				if case .string(let name) = arguments[1] {
					instanceName = name
				} else {
					return .init(type: .macro, description: "Expected value of type STRING.", line: line, word: 2)
				}
				
				if structureNamespace == "" {
					let (_, _, error) = self.interpreter.interpret(structureCode, isInsideCodeBlock: true, namespace: instanceName)
					
					if let error = error {
						return error
					}
				} else {
					let (_, _, error) = self.interpreter.interpret(structureCode, isInsideCodeBlock: true, namespace: structureNamespace + "::" + instanceName)
					
					if let error = error {
						return error
					}
				}
				
				return nil
			}
			
			GBMacro("MODULO") { arguments, line in
				if arguments.count != 3 {
					return .init(type: .macro, description: "Expected 3 arguments, got \(arguments.count).", line: line, word: 0)
				}
				
				var variable = ""
				var number = 0
				var modulo = 0
				
				if case .pointer(let value) = arguments[0] {
					if storage.variableExists(value) {
						if storage[value].type == .number {
							variable = value
						} else {
							return .init(type: .macro, description: "Variable \"\(value)\" should be of type NUMBER.", line: line, word: 0)
						}
					} else {
						return .init(type: .macro, description: "Variable \"\(value)\" doesn't exist.", line: line, word: 0)
					}
				} else {
					return .init(type: .macro, description: "Invalid argument type. Expected pointer, got \"\(arguments[0].type)\"", line: line, word: 0)
				}
				
				if case .number(let value) = arguments[1] {
					number = Int(value)
				} else {
					return .init(type: .macro, description: "Invalid argument type. Expected NUMBER, got \"\(arguments[1].type)\"", line: line, word: 0)
				}
				
				if case .number(let value) = arguments[2] {
					modulo = Int(value)
				} else {
					return .init(type: .macro, description: "Invalid argument type. Expected NUMBER, got \"\(arguments[2].type)\"", line: line, word: 0)
				}
				
				storage[variable] = .init(value: String(Float(number % modulo)), type: .number, scope: storage[variable].scope)
								 
				return nil
			}
			
			GBMacro("DYN_VAR_MAKE") { arguments, line in
				if arguments.count != 3 {
					return .init(type: .macro, description: "Expected 3 arguments, got \(arguments.count).", line: line, word: 0)
				}
				
				var name = ""
				var value = ""
				var type: GBStorage.ValueType! = nil
				
				if case .string(let value) = arguments[0] {
					if let convertedType = GBStorage.ValueType(rawValue: value.uppercased()) {
						type = convertedType
					} else {
						return .init(type: .macro, description: "Invalid type. Expected a type, for example: NUMBER, STRING or BOOL.", line: line, word: 0)
					}
				} else {
					return .init(type: .macro, description: "Invalid value: \(arguments[0])", line: line, word: 0)
				}
				
				if case .string(let value) = arguments[1] {
					name = value
				} else {
					return .init(type: .macro, description: "Invalid value: \(arguments[1])", line: line, word: 0)
				}
				
				if case .string(let string) = arguments[2] {
					value = string
				} else if case .number(let number) = arguments[2] {
					value = String(number)
				} else if case .bool(let bool) = arguments[2] {
					value = String(bool)
				} else {
					return .init(type: .macro, description: "Invalid value: \(arguments[2])", line: line, word: 0)
				}
				
				storage[name] = .init(value: value, type: type, scope: .global)
				
				return nil
			}
			
			GBMacro("DYN_VAR_READ") { arguments, line in
				if arguments.count != 3 {
					return .init(type: .macro, description: "Expected 3 arguments, got \(arguments.count).", line: line, word: 0)
				}
				
				var name = ""
				var pointer = ""
				var type: GBStorage.ValueType! = nil
				
				if case .string(let value) = arguments[0] {
					if let convertedType = GBStorage.ValueType(rawValue: value.uppercased()) {
						type = convertedType
					} else {
						return .init(type: .macro, description: "Invalid type. Expected a type, for example: NUMBER, STRING or BOOL.", line: line, word: 0)
					}
				} else {
					return .init(type: .macro, description: "Invalid value: \(arguments[0])", line: line, word: 0)
				}
				
				if case .string(let value) = arguments[1] {
					if storage.variableExists(value) {
						name = value
					} else {
						return .init(type: .macro, description: "Variable \"\(value)\" doesn't exist.", line: line, word: 0)
					}
				} else {
					return .init(type: .macro, description: "Invalid value: \(arguments[1])", line: line, word: 0)
				}
				
				if case .pointer(let value) = arguments[2] {
					if storage.variableExists(value) {
						let variable = storage[value]
						
						if variable.type != type {
							return .init(type: .macro, description: "Type of variable is and specified type are not the same.", line: line, word: 0)
						}
						
						pointer = value
					} else {
						return .init(type: .macro, description: "Variable \"\(value)\" doesn't exist.", line: line, word: 0)
					}
				} else {
					return .init(type: .macro, description: "Invalid value: \(arguments[2])", line: line, word: 0)
				}
				
				storage[pointer] = .init(value: storage[name].value, type: type, scope: .global)
				
				return nil
			}
			
			GBMacro("ENABLE") { arguments, line in
				if arguments.count == 1 {
					if case .string(let value) = arguments[0] {
						storage.disabledMacros.remove(value)
					} else {
						return .init(type: .macro, description: "Expected STRING, got \(arguments[0].type).", line: line, word: 0)
					}
				} else {
					return .init(type: .macro, description: "Expected 1 argument, got \(arguments.count).", line: line, word: 0)
				}
				
				return nil
			}
			
			GBMacro("DISABLE") { arguments, line in
				if arguments.count == 1 {
					if case .string(let value) = arguments[0] {
						storage.disabledMacros.insert(value)
					} else {
						return .init(type: .macro, description: "Expected STRING, got \(arguments[0].type).", line: line, word: 0)
					}
				} else {
					return .init(type: .macro, description: "Expected 1 argument, got \(arguments.count).", line: line, word: 0)
				}
				
				return nil
			}
			
			GBMacro("USE") { arguments, line in
				if arguments.count != 1 {
					return .init(type: .macro, description: "Expected 1 argument, got \(arguments.count).", line: line, word: 0)
				}
				
				if case .string(let value) = arguments[0] {
					if Bundle.currentModule.url(forResource: value, withExtension: "txt") != nil {
						let standardLibrary = String(data: FileManager.default.contents(atPath: Bundle.currentModule.url(forResource: value, withExtension: "txt")!.path)!, encoding: .utf8)!
						return self.load(with: standardLibrary, filePath: "")
					}
					
					let filePath = URL(fileURLWithPath: self.filePath).deletingLastPathComponent()
					
					var url = URL(fileURLWithPath: value)
					
					if url.path == "std" {
						let standardLibrary = String(data: FileManager.default.contents(atPath: Bundle.main.url(forResource: "standard", withExtension: "txt")!.path)!, encoding: .utf8)!
						return self.load(with: standardLibrary, filePath: url.path)
					}
					
					if url.pathComponents[0] == "~" {
						url = URL(fileURLWithPath: (url.absoluteString as NSString).expandingTildeInPath)
					} else {
						let full = filePath.path + (!filePath.path.hasSuffix("/") && !url.path.hasPrefix("/") ? "/" : "") + url.path
						url = URL(fileURLWithPath: full)
					}
					
					var isDirectory: ObjCBool = false
					
					if !FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
						return .init(type: .macro, description: "Library doesn't exist.", line: line, word: 0)
					}
					
					if isDirectory.boolValue {
						return .init(type: .macro, description: "Library can't be directory.", line: line, word: 0)
					}
					
					if let code = String(data: FileManager.default.contents(atPath: url.path)!, encoding: .utf8) {
						return self.load(with: code, filePath: url.path)
					} else {
						return .init(type: .macro, description: "File is empty.", line: line, word: 0)
					}
				} else if case .url(let url) = arguments[0] {
					let filePath = URL(fileURLWithPath: self.filePath).deletingLastPathComponent()
					var url = url
					
					if url.path == "std" {
						let standardLibrary = String(data: FileManager.default.contents(atPath: Bundle.main.url(forResource: "standard", withExtension: "txt")!.path)!, encoding: .utf8)!
						return self.load(with: standardLibrary, filePath: url.path)
					}
					
					if url.pathComponents[0] == "~" {
						url = URL(fileURLWithPath: (url.absoluteString as NSString).expandingTildeInPath)
					} else {
						let full = filePath.path + (!filePath.path.hasSuffix("/") && !url.path.hasPrefix("/") ? "/" : "") + url.path
						url = URL(fileURLWithPath: full)
					}
					
					var isDirectory: ObjCBool = false
					
					if !FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
						return .init(type: .macro, description: "Library doesn't exist.", line: line, word: 0)
					}
					
					if isDirectory.boolValue {
						return .init(type: .macro, description: "Library can't be directory.", line: line, word: 0)
					}
					
					if let code = String(data: FileManager.default.contents(atPath: url.path)!, encoding: .utf8) {
						return self.load(with: code, filePath: url.path)
					} else {
						return .init(type: .macro, description: "File is empty.", line: line, word: 0)
					}
				} else {
					return .init(type: .macro, description: "Expected URL, got \(arguments[0].type).", line: line, word: 0)
				}
			}
			
			GBMacro("FREE") { arguments, line in
				if arguments.count != 1 {
					return .init(type: .macro, description: "Expect 1 argument, got \(arguments.count).", line: line, word: 0)
				}
				
				if case .pointer(let variable) = arguments[0] {
					if storage.variableExists(variable) {
						storage.deleteVariable(variable)
					} else {
						var namespaces = variable.components(separatedBy: "::")
						namespaces = namespaces.map { "[\($0)]" }
						
						var objectName = namespaces.joined(separator: "")
						
						var variablesCount = 0
						
						for (name, _) in storage.variables {
							if name.hasPrefix(objectName) {
								storage.deleteVariable(name)
								variablesCount += 1
							}
						}
						
						var functionsCount = 0
						
						for (name, _) in storage.functions {
							if name.hasPrefix(objectName) {
								storage.functions.removeValue(forKey: name)
								
								functionsCount += 1
							}
						}
						
						if variablesCount == 0 && functionsCount == 0 {
							return .init(type: .macro, description: "Object \"\(variable)\" doesn't exist.", line: line, word: 0)
						}
					}
				} else {
					return .init(type: .macro, description: "Expected POINTER, got \(arguments[0].type).", line: line, word: 0)
				}
				
				return nil
			}
			
			GBMacro("RAND") { arguments, line in
				if arguments.count == 3 {
					var variable = ""
					var min: Float = 0
					var max: Float = 0
					
					if case .pointer(let value) = arguments[0] {
						if storage.variableExists(value) {
							if storage[value].type == .number {
								variable = value
							} else {
								return .init(type: .macro, description: "Variable \"\(value)\" should be of type NUMBER.", line: line, word: 0)
							}
						} else {
							return .init(type: .macro, description: "Variable \"\(value)\" doesn't exist.", line: line, word: 0)
						}
					} else {
						return .init(type: .macro, description: "Invalid argument type. Expected pointer, got \"\(arguments[0].type)\"", line: line, word: 0)
					}
					
					if case .number(let value) = arguments[1] {
						min = value
					} else {
						return .init(type: .macro, description: "Invalid argument type. Expected NUMBER, got \"\(arguments[1].type)\"", line: line, word: 0)
					}
					
					if case .number(let value) = arguments[2] {
						max = value
					} else {
						return .init(type: .macro, description: "Invalid argument type. Expected NUMBER, got \"\(arguments[2].type)\"", line: line, word: 0)
					}
					
					if min > max {
						return .init(type: .macro, description: "Min number must be lower than max number.", line: line, word: 0)
					}
					
					let randomNumber = Int.random(in: Int(min)...Int(max))
					
					storage[variable] = .init(value: String(Float(randomNumber)), type: .number, scope: storage[variable].scope)
				} else {
					return .init(type: .macro, description: "Invalid number of arguments for RAND macro.", line: line, word: 0)
				}
				
				return nil
			}
			
			GBMacro("ERROR") { arguments, line in
				if arguments.count == 1 {
					if case .string(let value) = arguments[0] {
						return .init(type: .macro, description: value, line: line, word: 0)
					} else {
						return .init(type: .macro, description: "Expected STRING, got \"\(arguments[0].type)\".", line: line, word: 0)
					}
				} else {
					return .init(type: .macro, description: "Invalid number of arguments for ERROR macro.", line: line, word: 0)
				}
			}
			
			GBMacro("ASSIGN") { arguments, line in
				var modifiedVariable = ""
				
				var typeOfNewValue: GBStorage.ValueType = .null
				var newValue = ""
				
				guard let modifiedVariableToken = arguments[safely: 0] else {
					return .init(type: .macro, description: "Pointer to variable is required.", line: line, word: 0)
				}
				
				if case .pointer(let key) = modifiedVariableToken {
					if storage.variableExists(key) {
						modifiedVariable = key
					} else {
						return .init(type: .macro, description: "Variable \"\(key)\" doesn't exist.", line: line, word: 0)
					}
				} else {
					return .init(type: .macro, description: "Expected pointer, but got something else.", line: line, word: 0)
				}
				
				guard let newValueToken = arguments[safely: 1] else {
					return .init(type: .macro, description: "Pointer to variable is required.", line: line, word: 0)
				}
				
				if case .number(let value) = newValueToken {
					typeOfNewValue = .number
					newValue = String(value)
				} else if case .string(let value) = newValueToken {
					typeOfNewValue = .string
					newValue = value
				} else if case .bool(let value) = newValueToken {
					typeOfNewValue = .bool
					newValue = String(value)
				} else {
					return .init(type: .macro, description: "Invalid type. Expected number, string or bool.", line: line, word: 0)
				}
				
				let variable = self.storage[modifiedVariable]
				
				if variable.type == typeOfNewValue {
					self.storage[modifiedVariable] = .init(value: newValue, type: variable.type, scope: storage[modifiedVariable].scope)
				} else {
					return .init(type: .macro, description: "Unmatching types. Expected \"\(variable.type.rawValue)\", got \"\(typeOfNewValue.rawValue)\".", line: line, word: 0)
				}
				
				return nil
			}
			
			GBMacro("PRINT") { arguments, line in
				if arguments.count == 1 {
					if case .string(let text) = arguments[0] {
						self.console.text(text)
					} else if case .bool(let bool) = arguments[0] {
						self.console.text(String(bool))
					} else if case .number(let number) = arguments[0] {
						self.console.text(String(number))
					} else {
						return .init(type: .macro, description: "Invalid type. Expected STRING, BOOL or NUMBER.", line: line, word: 0)
					}
				} else {
					return .init(type: .macro, description: "Too many arguments for PRINT macro.", line: line, word: 0)
				}
				
				return nil
			}
			
			GBMacro("PRINTLN") { arguments, line in
				if arguments.count == 1 {
					if case .string(let text) = arguments[0] {
						self.console.text(text + "\n")
					} else if case .bool(let bool) = arguments[0] {
						self.console.text(String(bool) + "\n")
					} else if case .number(let number) = arguments[0] {
						self.console.text(String(number) + "\n")
					} else {
						return .init(type: .macro, description: "Invalid type. Expected STRING, BOOL or NUMBER.", line: line, word: 0)
					}
				} else {
					return .init(type: .macro, description: "Too many arguments for PRINTLN macro.", line: line, word: 0)
				}
				
				return nil
			}
			
			GBMacro("INPUT") { arguments, line in
				if arguments.count == 2 || arguments.count == 3 {
					var type: GBStorage.ValueType = .null

					var ignoreInputType = false
					
					if arguments.count == 3 {
						if case .bool(let _) = arguments[2] {
							ignoreInputType = true
						}
					}
					
					if case .string(let value) = arguments[0] {
						if let convertedType = GBStorage.ValueType(rawValue: value.uppercased()) {
							type = convertedType
						} else {
							return .init(type: .macro, description: "Invalid type. Expected a type, for example: NUMBER, STRING or BOOL.", line: line, word: 0)
						}
					} else {
						return .init(type: .macro, description: "Invalid type. Expected a type, for example: NUMBER, STRING or BOOL.", line: line, word: 0)
					}
					
					if case .pointer(let key) = arguments[1] {
						if !self.storage.variableExists(key) {
							return .init(type: .macro, description: "No variable for pointer exists.", line: line, word: 0)
						}

						let variable = self.storage[key]
						
						if variable.type != type {
							return .init(type: .macro, description: "Explicit type and variable type don't match.", line: line, word: 0)
						}

						var input = self.console.input()

						if (input.detectType() == variable.type) || ignoreInputType {
							if input.detectType() == .number {
								if !input.contains(".") {
									input.append(".0")
								}
							}
							
							self.storage[key] = .init(value: input, type: variable.type, scope: storage[key].scope)
							return nil
						} else {
							return .init(type: .macro, description: "Provided input doesn't match the type of variable \"\(key)\". Expected \"\(variable.type.rawValue)\", got \"\(input.detectType().rawValue)\".", line: line, word: 0)
						}
					} else {
						return .init(type: .macro, description: "Invalid type. Expected a pointer.", line: line, word: 0)
					}
				}
				
				return .init(type: .macro, description: "Too many or too little arguments for INPUT macro.", line: line, word: 0)
			}
		}
	}
}

func printLine(line: UInt = #line) {
	print(line)
}

class DefaultConsole: GBConsole {
	func warning(_ string: String) {
		text("[WARNING] \(string)")
	}
	
	func text(_ string: String) {
		print(string, terminator: "")
	}
	
	func input() -> String {
		readLine()!
	}
}

class DefaultErrorHandler: GBErrorHandler {
	func handle(_ error: GBError) {
		let console = GBCore.defaultConfiguration.console
		
		let errorMessage = """
  \n
  [\(error.type.rawValue.uppercased()) ERROR] \(error.line + 1):\(error.word + 1)
  \(error.description)
  \n
  """
		
		console.text(errorMessage)
	}
}
