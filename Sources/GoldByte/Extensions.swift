//
//  Extensions.swift
//  
//
//  Created by Wiktor Wójcik on 22/03/2022.
//

import Foundation

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
		!isString && !self.contains(where: { "£§!#$%@^&*()+-={}[]|<>?;'\\,./~".contains($0) })
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
