//
//  GBStorage.swift
//  GoldByte
//
//  Created by Wiktor Wójcik on 24/11/2021.
//

import Foundation

class GBStorage {
	typealias Scope = GBInterpreter.Scope
	typealias GBMacroAction = GBCore.GBMacroAction
	
	var errorHandler: GBErrorHandler
	var macros: [String: GBMacroAction]
	
	var functions = [String: GBFunction]()
	var disabledMacros: Set<String> = ["dyn_var_make", "dyn_var_read"]
	var variables = [String: GBVariable]()
	var builtInFunctions = [
		"@print": printBuiltinFunction,
		"@println": printlnBuiltinFunction,
		"@read": readBuiltinFunction,
		"@rand": randBuiltinFunction,
	]
	
	init(errorHandler: GBErrorHandler, @GBMacrosBuilder macrosBuilder: () -> [String: GBMacroAction]) {
		self.errorHandler = errorHandler
		macros = macrosBuilder()
	}
	
	init(errorHandler: GBErrorHandler, macros: [String: GBMacroAction]) {
		self.errorHandler = errorHandler
		self.macros = macros
	}
	
	static func buildMacros(@GBMacrosBuilder macrosBuilder: () -> [String: GBMacroAction]) -> [String: GBMacroAction] {
		macrosBuilder()
	}
	
	enum ValueType: String, CaseIterable {
		// These are helper types
		case null = "NULL"
		case void = "VOID"
		case variable = "VARIABLE"
		
		case string = "STRING"
		case number = "NUMBER"
		case bool = "BOOL"
		case url = "URL"
		case any = "ANY"
	}
	
	func deleteScope(_ scope: Scope) {
		for (key, variable) in variables {
			if variable.scope == scope {
				variables.removeValue(forKey: key)
			}
		}
	}
	
	func generateVariables(forFunction functionName: String, withArguments arguments: [GBFunctionArgument], withScope scope: Scope) {
		var namespaces = functionName.components(separatedBy: "::")
		var name = namespaces.removeLast()
		
		namespaces = namespaces.map { "[\($0)]" }
		
		name = namespaces.joined(separator: "") + name
		
		let function = functions[name]!

		for (n, argument) in arguments.enumerated() {
			self[function.definition.arguments[n].name] = .init(value: argument.type == .string ? argument.value.replaceKeywordCharacters() : argument.value, type: argument.type, scope: scope)
		}
	}
	
	func deleteVariable(_ key: String) {
		variables.removeValue(forKey: key)
	}
	
	func saveFunction(_ definition: GBFunctionDefinition, codeBlock: [[GBToken]]) {
		var definitionWithNamespace = definition
		
		var namespaces = definition.name.components(separatedBy: "::")
		var name = namespaces.removeLast()
		
		namespaces = namespaces.map { "[\($0)]" }
		
		name = namespaces.joined(separator: "") + name
		
		definitionWithNamespace.name = name
		
		functions[name] = .init(definition: definitionWithNamespace, codeBlock: codeBlock)
	}
	
	var structs: [String: [[GBToken]]] = [:]
	
	func getFunction(_ name: String, arguments: [GBFunctionArgument], line: Int) -> ([[GBToken]]?, GBStorage.ValueType?, GBError?) {
		var namespaces = name.components(separatedBy: "::")
		var name = namespaces.removeLast()
		
		namespaces = namespaces.map { "[\($0)]" }
		
		name = namespaces.joined(separator: "") + name
		
		if let function = functions[name] {
			if arguments.count != function.definition.arguments.count {
				return (nil, nil, .init(type: .panic, description: "Expected \(function.definition.arguments.count) arguments, got \(arguments.count).", line: line, word: 0))
			}
			
			for (n, functionDefinedArgument) in function.definition.arguments.enumerated() {
				if functionDefinedArgument.type.rawValue != arguments[n].type.rawValue {
					if functionDefinedArgument.type != .any {
						return (nil, nil, .init(type: .panic, description: "Invalid type for argument for function \"\(name)\". Expected \(functionDefinedArgument.type), got \(arguments[n].type).", line: line, word: 0))
					}
				}
			}
			
			return (function.codeBlock, function.definition.returnType == .void ? nil : function.definition.returnType, nil)
		} else {
			return (nil, nil, .init(type: .panic, description: "No function found named \"\(name)\".", line: line, word: 0))
		}
	}
	
	subscript(_ key: String) -> GBVariable {
		set {
			var namespaces = key.components(separatedBy: "::")
			var key = namespaces.removeLast()
			
			namespaces = namespaces.map { "[\($0)]" }
			
			key = namespaces.joined(separator: "") + key

			if let variable = variables[key] {
				if variable.type == newValue.type {
					if !variable.isConstant {
						variables[key] = newValue
					} else {
						errorHandler.handle(.init(type: .panic, description: "\"\(key)\" is a constant. New value will be ignored, but undefined actions may take place."))
					}
				} else {
					errorHandler.handle(.init(type: .panic, description: "Expected \"\(variable.type)\", got \"\(newValue.type)\"."))
				}
			} else {
				variables[key] = newValue
			}
		}
		
		get {
			var namespaces = key.components(separatedBy: "::")
			var key = namespaces.removeLast()
			
			namespaces = namespaces.map { "[\($0)]" }
			
			key = namespaces.joined(separator: "") + key
			
			return variables[key] ?? GBVariable(value: "", type: .null, scope: .global, isConstant: true)
		}
	}
	
	func variableExists(_ key: String) -> Bool {
		self[key].type != .null
	}
	
	func handleBuiltinFunction(_ name: String, arguments: [GBFunctionArgument], line: Int) -> (GBValue?, GBError?) {
		if let function = builtInFunctions[name] {
			let (output, error) = function.code(arguments, line)
			
			if let error = error {
				return (nil, error)
			}
			
			return (output, nil)
		} else {
			return (nil, .init(type: .panic, description: "There is no builtin function with name \"\(name)\".", line: line, word: 1))
		}
	}
	
	func handleMacro(_ key: String, arguments: [GBValue], line: Int, namespace: String) -> GBError? {
		if let action = macros[key] {
			if !disabledMacros.contains(key) {
				return action(arguments, line, namespace)
			} else {
				return .init(type: .panic, description: "Macro [\(key)] is disabled.", line: line, word: 0)
			}
		} else {
			return .init(type: .panic, description: "Unknown macro: [\(key)]", line: line, word: 0)
		}
	}
}

struct GBVariable {
	var value: String
	var type: GBStorage.ValueType
	var scope: GBInterpreter.Scope
	var isConstant: Bool = false
}


public struct GBMacro {
	typealias GBMacroAction = GBCore.GBMacroAction
	
	var key: String
	var action: GBMacroAction
	
	init(_ key: String, action: @escaping GBMacroAction) {
		self.key = key
		self.action = action
	}
}

@resultBuilder
public struct GBMacrosBuilder {
	typealias GBMacroAction = GBCore.GBMacroAction
	
	static func buildBlock(_ macros: GBMacro...) -> [String: GBMacroAction] {
		var builtMacros: [String: GBMacroAction] = [:]
		
		for macro in macros {
			builtMacros[macro.key] = macro.action
		}
		
		return builtMacros
	}
}

struct GBBuiltinFunction {
	var code: ([GBFunctionArgument], Int) -> (GBValue?, GBError?)
}

struct GBFunction {
	let definition: GBFunctionDefinition
	var codeBlock: [[GBToken]]
}

struct GBFunctionDefinition {
	var name: String
	let returnType: GBStorage.ValueType
	var arguments: [GBFunctionArgumentDefinition]
}

struct GBFunctionArgumentDefinition {
	let name: String
	let type: GBStorage.ValueType
}

struct GBFunctionArgument {
	let value: String
	let type: GBStorage.ValueType
}

struct GBFunctionInvocation {
	let name: String
	let arguments: [GBFunctionArgument]
}
