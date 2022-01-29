//
//  GBValue.swift
//  GoldByte
//
//  Created by Wiktor Wójcik on 24/11/2021.
//

import Foundation

public enum GBValue: Equatable {
	public static func == (lhs: GBValue, rhs: GBValue) -> Bool {
		if case .string(let leftValue) = lhs {
			if case .string(let rightValue) = rhs {
				return leftValue == rightValue
			}
		} else if case .bool(let leftValue) = lhs {
			if case .bool(let rightValue) = rhs {
				return leftValue == rightValue
			}
		} else if case .number(let leftValue) = lhs {
			if case .number(let rightValue) = rhs {
				return leftValue == rightValue
			}
		} else if case .url(let leftValue) = lhs {
			if case .url(let rightValue) = rhs {
				return leftValue == rightValue
			}
		}
		
		return false
	}
	
	case string(String)
	case bool(Bool)
	case number(Float)
	case pointer(String)
	case url(URL)
	case array([GBValue])
	
	func getValue<T>(forType type: T.Type) -> T? {
		if case .bool(let boolean) = self {
			return boolean as Any as? T
		} else if case .number(let number) = self {
			return number as Any as? T
		} else if case .string(let string) = self {
			return string as Any as? T
		} else if case .url(let url) = self {
			return url as Any as? T
		}
		
		return nil
	}
	
	func getValue() -> String {
		if case .bool(let boolean) = self {
			return String(boolean)
		} else if case .number(let number) = self {
			return String(number)
		} else if case .string(let string) = self {
			return string
		} else if case .url(let url) = self {
			return url.absoluteString
		}
		
		return ""
	}
	
	var type: String {
		switch self {
			case .string(_):
				return "STRING"
			case .number(_):
				return "NUMBER"
			case .bool(_):
				return "BOOL"
			case .pointer(_):
				return "POINTER"
			case .url(_):
				return "URL"
			case .array(_):
				return "ARRAY"
		}
		
		return "NULL"
	}
}
