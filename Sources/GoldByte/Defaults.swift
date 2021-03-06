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
			GBMacro("new") { arguments, line, _ in
				if arguments.count != 2 {
					return .init(type: .panic, description: "Expected 2 arguments, got \(arguments.count).", line: line, word: 0)
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
						return .init(type: .panic, description: "Structure with name \"\(id)\" doesn't exist.", line: line, word: 1)
					}
				} else {
					return .init(type: .panic, description: "Expected value of type STRING or plain text.", line: line, word: 1)
				}
				
				if case .string(let name) = arguments[1] {
					instanceName = name
				} else {
					return .init(type: .panic, description: "Expected value of type STRING.", line: line, word: 2)
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
			
			GBMacro("dyn_var_make") { arguments, line, _ in
				if arguments.count != 3 {
					return .init(type: .panic, description: "Expected 3 arguments, got \(arguments.count).", line: line, word: 0)
				}
				
				var name = ""
				var value = ""
				var type: GBStorage.ValueType! = nil
				
				if case .string(let value) = arguments[0] {
					if let convertedType = GBStorage.ValueType(rawValue: value.uppercased()) {
						type = convertedType
					} else {
						return .init(type: .panic, description: "Invalid type. Expected a type, for example: NUMBER, STRING or BOOL.", line: line, word: 0)
					}
				} else {
					return .init(type: .panic, description: "Invalid value: \(arguments[0])", line: line, word: 0)
				}
				
				if case .string(let value) = arguments[1] {
					name = value
				} else {
					return .init(type: .panic, description: "Invalid value: \(arguments[1])", line: line, word: 0)
				}
				
				if case .string(let string) = arguments[2] {
					value = string
				} else if case .number(let number) = arguments[2] {
					value = String(number)
				} else if case .bool(let bool) = arguments[2] {
					value = String(bool)
				} else {
					return .init(type: .panic, description: "Invalid value: \(arguments[2])", line: line, word: 0)
				}
				
				storage[name] = .init(value: value, type: type, scope: .global)
				
				return nil
			}
			
			GBMacro("dyn_var_read") { arguments, line, _ in
				if arguments.count != 3 {
					return .init(type: .panic, description: "Expected 3 arguments, got \(arguments.count).", line: line, word: 0)
				}
				
				var name = ""
				var pointer = ""
				var type: GBStorage.ValueType! = nil
				
				if case .string(let value) = arguments[0] {
					if let convertedType = GBStorage.ValueType(rawValue: value.uppercased()) {
						type = convertedType
					} else {
						return .init(type: .panic, description: "Invalid type. Expected a type, for example: NUMBER, STRING or BOOL.", line: line, word: 0)
					}
				} else {
					return .init(type: .panic, description: "Invalid value: \(arguments[0])", line: line, word: 0)
				}
				
				if case .string(let value) = arguments[1] {
					if storage.variableExists(value) {
						name = value
					} else {
						return .init(type: .panic, description: "Variable \"\(value)\" doesn't exist.", line: line, word: 0)
					}
				} else {
					return .init(type: .panic, description: "Invalid value: \(arguments[1])", line: line, word: 0)
				}
				
				if case .pointer(let value) = arguments[2] {
					if storage.variableExists(value) {
						let variable = storage[value]
						
						if variable.type != type {
							return .init(type: .panic, description: "Type of variable is and specified type are not the same.", line: line, word: 0)
						}
						
						pointer = value
					} else {
						return .init(type: .panic, description: "Variable \"\(value)\" doesn't exist.", line: line, word: 0)
					}
				} else {
					return .init(type: .panic, description: "Invalid value: \(arguments[2])", line: line, word: 0)
				}
				
				storage[pointer] = .init(value: storage[name].value, type: type, scope: .global)
				
				return nil
			}
			
			GBMacro("enable") { arguments, line, _ in
				if arguments.count == 1 {
					if case .string(let value) = arguments[0] {
						storage.disabledMacros.remove(value)
					} else {
						return .init(type: .panic, description: "Expected STRING, got \(arguments[0].type).", line: line, word: 0)
					}
				} else {
					return .init(type: .panic, description: "Expected 1 argument, got \(arguments.count).", line: line, word: 0)
				}
				
				return nil
			}
			
			GBMacro("disable") { arguments, line, _ in
				if arguments.count == 1 {
					if case .string(let value) = arguments[0] {
						storage.disabledMacros.insert(value)
					} else {
						return .init(type: .panic, description: "Expected STRING, got \(arguments[0].type).", line: line, word: 0)
					}
				} else {
					return .init(type: .panic, description: "Expected 1 argument, got \(arguments.count).", line: line, word: 0)
				}
				
				return nil
			}
			
			GBMacro("use") { arguments, line, _ in
				if arguments.count != 1 {
					return .init(type: .panic, description: "Expected 1 argument, got \(arguments.count).", line: line, word: 0)
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
						return .init(type: .panic, description: "Library doesn't exist.", line: line, word: 0)
					}
					
					if isDirectory.boolValue {
						return .init(type: .panic, description: "Library can't be directory.", line: line, word: 0)
					}
					
					if let code = String(data: FileManager.default.contents(atPath: url.path)!, encoding: .utf8) {
						return self.load(with: code, filePath: url.path)
					} else {
						return .init(type: .panic, description: "File is empty.", line: line, word: 0)
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
						return .init(type: .panic, description: "Library doesn't exist.", line: line, word: 0)
					}
					
					if isDirectory.boolValue {
						return .init(type: .panic, description: "Library can't be directory.", line: line, word: 0)
					}
					
					if let code = String(data: FileManager.default.contents(atPath: url.path)!, encoding: .utf8) {
						return self.load(with: code, filePath: url.path)
					} else {
						return .init(type: .panic, description: "File is empty.", line: line, word: 0)
					}
				} else {
					return .init(type: .panic, description: "Expected URL, got \(arguments[0].type).", line: line, word: 0)
				}
			}
			
			GBMacro("free") { arguments, line, _ in
				if arguments.count != 1 {
					return .init(type: .panic, description: "Expect 1 argument, got \(arguments.count).", line: line, word: 0)
				}
				
				if case .pointer(let variable) = arguments[0] {
					if storage.variableExists(variable) {
						storage.deleteVariable(variable)
					} else {
						var namespaces = variable.components(separatedBy: "::")
						namespaces = namespaces.map { "[\($0)]" }
						
						let objectName = namespaces.joined(separator: "")
						
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
							return .init(type: .panic, description: "Object \"\(variable)\" doesn't exist.", line: line, word: 0)
						}
					}
				} else {
					return .init(type: .panic, description: "Expected POINTER, got \(arguments[0].type).", line: line, word: 0)
				}
				
				return nil
			}
			
			GBMacro("throw") { arguments, line, _ in
				if arguments.count == 1 {
					if case .string(let value) = arguments[0] {
						return .init(type: .thrown, description: value, line: line, word: 0)
					} else {
						return .init(type: .thrown, description: "Expected STRING, got \"\(arguments[0].type)\".", line: line, word: 0)
					}
				} else {
					return .init(type: .panic, description: "Invalid number of arguments for THROW macro.", line: line, word: 0)
				}
			}
			
			GBMacro("panic") { arguments, line, _ in
				if arguments.count == 1 {
					if case .string(let value) = arguments[0] {
						return .init(type: .panic, description: value, line: line, word: 0)
					} else {
						return .init(type: .panic, description: "Expected STRING, got \"\(arguments[0].type)\".", line: line, word: 0)
					}
				} else {
					return .init(type: .panic, description: "Invalid number of arguments for PANIC macro.", line: line, word: 0)
				}
			}
			
			GBMacro("set") { arguments, line, namespace in
				var modifiedVariable = ""
				
				var typeOfNewValue: GBStorage.ValueType = .null
				var newValue = ""
				
				guard let modifiedVariableToken = arguments[safely: 0] else {
					return .init(type: .panic, description: "Pointer to variable is required.", line: line, word: 0)
				}
				
				if case .pointer(let key) = modifiedVariableToken {
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
					
					if storage.variableExists(key) {
						modifiedVariable = key
					} else {
						return .init(type: .panic, description: "Variable \"\(key)\" doesn't exist.", line: line, word: 0)
					}
				} else {
					return .init(type: .panic, description: "Expected pointer, but got something else.", line: line, word: 0)
				}
				
				guard let newValueToken = arguments[safely: 1] else {
					return .init(type: .panic, description: "Pointer to variable is required.", line: line, word: 0)
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
					return .init(type: .panic, description: "Invalid type. Expected number, string or bool.", line: line, word: 0)
				}
				
				let variable = self.storage[modifiedVariable]
				
				if variable.type == typeOfNewValue {
					self.storage[modifiedVariable] = .init(value: newValue, type: variable.type, scope: storage[modifiedVariable].scope)
				} else {
					return .init(type: .panic, description: "Unmatching types. Expected \"\(variable.type.rawValue)\", got \"\(typeOfNewValue.rawValue)\".", line: line, word: 0)
				}
				
				return nil
			}
		}
	}
}

let printBuiltinFunction = GBBuiltinFunction { arguments, line in
	if arguments.count != 1 {
		return (nil, .init(type: .panic, description: "Print function expects only 1 argument.", line: line, word: 1))
	}
	
	print(arguments[0].value, terminator: "")
	
	return (nil, nil)
}

let printlnBuiltinFunction = GBBuiltinFunction { arguments, line in
	if arguments.count != 1 {
		return (nil, .init(type: .panic, description: "Print function expects 1 argument.", line: line, word: 1))
	}
	
	print(arguments[0].value)
	
	return (nil, nil)
}

let readBuiltinFunction = GBBuiltinFunction { arguments, line in
	if arguments.count != 0 {
		return (nil, .init(type: .panic, description: "Read function expects 0 argument.", line: line, word: 1))
	}
	
	let output = readLine() ?? ""
	
	return (.string(output), nil)
}

let randBuiltinFunction = GBBuiltinFunction { arguments, line in
	if arguments.count == 2 {
		var min = 0
		var max = 0

		if arguments[0].type == .number {
			min = Int(arguments[0].value)!
		} else {
			return (nil, .init(type: .panic, description: "Invalid argument type. Expected NUMBER, got \"\(arguments[1].type)\"", line: line, word: 0))
		}
		
		if arguments[1].type == .number {
			max = Int(arguments[1].value)!
		} else {
			return (nil, .init(type: .panic, description: "Invalid argument type. Expected NUMBER, got \"\(arguments[2].type)\"", line: line, word: 0))
		}
		
		if min > max {
			return (nil, .init(type: .thrown, description: "Min number must be lower than max number.", line: line, word: 0))
		}
	
		let randomNumber = Int.random(in: Int(min)...Int(max))
		
		
		return (.number(Float(randomNumber)), nil)
	} else {
		return (nil, .init(type: .panic, description: "Invalid number of arguments for rand builtin function.", line: line, word: 0))
	}
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
