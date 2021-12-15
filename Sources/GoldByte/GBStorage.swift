//
//  GBStorage.swift
//  GoldByte
//
//  Created by Wiktor Wójcik on 24/11/2021.
//

import Foundation

class GBStorage {
	typealias Scope = GBInterpreter.Scope
	typealias GBMacroAction = ([GBValue], Int) -> GBError?
	
	var errorHandler: GBErrorHandler
	
	var macros: [String: GBMacroAction]
	
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
	
	var variables = [String: GBVariable]()
	
	func deleteScope(_ scope: Scope) {
		for (key, variable) in variables {
			if variable.scope == scope {
				variables.removeValue(forKey: key)
			}
		}
	}
	
	var functions: [String: GBFunction] = [:]
	
	var disabledMacros: Set<String> = ["DYN_VAR_MAKE", "DYN_VAR_READ"]
	
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
				return (nil, nil, .init(type: .interpreting, description: "Expected \(function.definition.arguments.count) arguments, got \(arguments.count).", line: line, word: 0))
			}
			
			for (n, functionDefinedArgument) in function.definition.arguments.enumerated() {
				if functionDefinedArgument.type.rawValue != arguments[n].type.rawValue {
					if functionDefinedArgument.type != .any {
						return (nil, nil, .init(type: .interpreting, description: "Invalid type for argument for function \"\(name)\". Expected \(functionDefinedArgument.type), got \(arguments[n].type).", line: line, word: 0))
					}
				}
			}
			
			return (function.codeBlock, function.definition.returnType == .void ? nil : function.definition.returnType, nil)
		} else {
			return (nil, nil, .init(type: .interpreting, description: "No function found named \"\(name)\".", line: line, word: 0))
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
					variables[key] = newValue
				} else {
					errorHandler.handle(.init(type: .type, description: "Expected \"\(variable.type)\", got \"\(newValue.type)\"."))
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
			
			return variables[key] ?? GBVariable(value: "", type: .null, scope: .global)
		}
	}
	
	func variableExists(_ key: String) -> Bool {
		self[key].type != .null
	}
	
	func handleMacro(_ key: String, arguments: [GBValue], line: Int) -> GBError? {
		if let action = macros[key] {
			if !disabledMacros.contains(key) {
				return action(arguments, line)
			} else {
				return .init(type: .type, description: "Macro [\(key)] is disabled.", line: line, word: 0)
			}
		} else {
			return .init(type: .type, description: "Unknown macro: [\(key)]", line: line, word: 0)
		}
	}
}

struct GBVariable {
	var value: String
	var type: GBStorage.ValueType
	var scope: GBInterpreter.Scope
}


struct GBMacro {
	typealias GBMacroAction = GBStorage.GBMacroAction
	
	var key: String
	var action: GBMacroAction
	
	init(_ key: String, action: @escaping GBMacroAction) {
		self.key = key
		self.action = action
	}
}

@resultBuilder
struct GBMacrosBuilder {
	typealias GBMacroAction = GBStorage.GBMacroAction
	
	static func buildBlock(_ macros: GBMacro...) -> [String: GBMacroAction] {
		var builtMacros: [String: GBMacroAction] = [:]
		
		for macro in macros {
			builtMacros[macro.key] = macro.action
		}
		
		return builtMacros
	}
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
