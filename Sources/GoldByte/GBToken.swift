//
//  GBToken.swift
//  GoldByte
//
//  Created by Wiktor Wójcik on 24/11/2021.
//

import Foundation
#if canImport(AppKit)
import AppKit
#endif

enum GBToken {
	case plain_text(String)
	case string(String)
	case number(Float)
	case macro(String)
	case url(URL)
	case variable_keyword
	case type(GBStorage.ValueType)
	case bool(Bool)
	case variable_type(GBStorage.ValueType)
	case pointer(String)
	case equation(GBEquation)
	case if_keyword
	case logical_expression(GBLogicalExpression)
	case code_block([[GBToken]])
	case function_keyword
	case function_definition(GBFunctionDefinition)
	case function_invocation(GBFunctionInvocation)
	case return_keyword
	case casted(GBValue, ValueType)
	case while_keyword
	case exit_keyword
	case namespace_keyword
	case struct_keyword
	case constant_keyword
	
	enum ValueType: String, CaseIterable {
		case string = "STRING"
		case number = "NUMBER"
		case bool = "BOOL"
		case url = "URL"
	}
	
	func cast(withStorage storage: GBStorage) -> (GBValue?, GBError?) {
		if case .casted(let value, let type) = self {
			var castedValue = ""

			switch value {
				case .string(let string):
					castedValue = string
				case .bool(let bool):
					castedValue = String(bool)
				case .number(let float):
					castedValue = String(float)
				case .pointer(let pointer):
					if storage.variableExists(pointer) {
						castedValue = storage[pointer].value
					} else {
						return (nil, .init(type: .interpreting, description: "Variable \"\(pointer)\" doesn't exist."))
					}
				case .url(let url):
					castedValue = url.path
				case .array(_):
					return (nil, .init(type: .interpreting, description: "Unable to cast array."))
			}
			
			switch type {
				case .string:
					return (.string(castedValue), nil)
				case .number:
					if let casted = Float(castedValue) {
						return (.number(casted), nil)
					} else {
						return (nil, .init(type: .interpreting, description: "Can't cast value \"\(castedValue)\" to \(type.rawValue)."))
					}
				case .bool:
					if let casted = Bool(castedValue) {
						return (.bool(casted), nil)
					} else {
						return (nil, .init(type: .interpreting, description: "Can't cast value \"\(castedValue)\" to \(type.rawValue)."))
					}
				case .url:
					if let casted = URL(string: castedValue) {
						return (.url(casted), nil)
					} else {
						return (nil, .init(type: .interpreting, description: "Can't cast value \"\(castedValue)\" to \(type.rawValue)."))
					}
				default:
					return (nil, .init(type: .interpreting, description: "Can't cast to chosen type."))
			}
		}
			
		return (nil, .init(type: .interpreting, description: "Use cast only on cast token."))
	}
}
