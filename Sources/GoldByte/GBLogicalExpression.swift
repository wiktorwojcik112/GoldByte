//
//  GBLogicalExpression.swift
//  GoldByte
//
//  Created by Wiktor Wójcik on 25/11/2021.
//

import Foundation

struct GBLogicalExpression {
	var elements: [GBLogicalElement]
	var storage: GBStorage
	
	static let operators = ["==", "&&", "||", "<", ">", "!="]
	
	func evaluate() -> (Bool?, GBError?) {
		var result = false
		var withoutVariables = [GBLogicalElement]()
		
		for element in elements {
			if case .variable(let key) = element {
				if storage.variableExists(key) {
					let variable = storage[key]
					
					if variable.type == .bool {
						withoutVariables.append(.value(.bool(Bool(variable.value)!)))
					} else if variable.type == .number {
						withoutVariables.append(.value(.number(Float(variable.value)!)))
					} else if variable.type == .string {
						withoutVariables.append(.value(.string(variable.value)))
					} else {
						return (nil, .init(type: .panic, description: "Invalid variable type."))
					}
				} else {
					return (nil, .init(type: .panic, description: "Variable of name \"\(key)\" doesn't exist."))
				}
			} else {
				withoutVariables.append(element)
			}
		}
		
		var comparisonsEvaluated = [GBLogicalElement]()
		
		var lastElement: GBLogicalElement? = nil
		var lastComparison: GBLogicalElement? = nil
		
		var lastWasElement = false
		
		var allowsOperator = false
		
		for element in withoutVariables {
			if !lastWasElement {
				if lastElement != nil && lastComparison != nil {
					if lastComparison! == .equals {
						comparisonsEvaluated.append(.value(.bool(lastElement! == element)))
					} else if lastComparison! == .not_equals {
						comparisonsEvaluated.append(.value(.bool(lastElement! != element)))
					} else if lastComparison! == .lowerThan {
						if case .value(let lastElementValue) = lastElement {
							if case .number(let lastValue) = lastElementValue {
								if case .value(let currentElementValue) = element {
									if case .number(let currentValue) = currentElementValue {
										comparisonsEvaluated.append(.value(.bool(lastValue < currentValue)))
									} else {
										return (nil, .init(type: .panic, description: "Expected number in comparison."))
									}
								}
							} else {
								return (nil, .init(type: .panic, description: "Expected number in comparison."))
							}
						}
					} else if lastComparison! == .higherThan {
						if case .value(let lastElementValue) = lastElement {
							if case .number(let lastValue) = lastElementValue {
								if case .value(let currentElementValue) = element {
									if case .number(let currentValue) = currentElementValue {
										comparisonsEvaluated.append(.value(.bool(lastValue > currentValue)))
									} else {
										return (nil, .init(type: .panic, description: "Expected number in comparison."))
									}
								}
							} else {
								return (nil, .init(type: .panic, description: "Expected number in comparison."))
							}
						}
					}
					
					lastElement = nil
					lastComparison = nil
					
					allowsOperator = true
				} else {
					lastElement = element
				}
				
				lastWasElement = true
			} else {
				if (element == .or || element == .and) && allowsOperator {
					comparisonsEvaluated.append(element)
					allowsOperator = false
				} else if (element == .equals || element == .lowerThan || element == .higherThan || element == .not_equals) && !allowsOperator {
					lastComparison = element
					allowsOperator = true
				} else {
					return (nil, .init(type: .panic, description: "Invalid arrangement in logical expression. Got \"\(element)\"."))
				}
				
				lastWasElement = false
			}
		}
		
		lastElement = nil
		var lastOperator: GBLogicalElement? = nil
		
		lastWasElement = false
		
		if comparisonsEvaluated.contains(.and) || comparisonsEvaluated.contains(.or) {
			for (n, element) in comparisonsEvaluated.enumerated() {
				if !lastWasElement {
					if lastElement != nil && lastOperator != nil {
						if case .value(let currentValue) = element {
							if case .value(let lastValue) = lastElement {
								if lastOperator == .and {
									lastElement = .value(.bool(lastValue.getValue(forType: Bool.self)! && currentValue.getValue(forType: Bool.self)!))
								} else if lastOperator == .or {
									lastElement = .value(.bool(lastValue.getValue(forType: Bool.self)! || currentValue.getValue(forType: Bool.self)!))
								}
							}
						}
						
						lastOperator = nil
					} else {
						lastElement = element
					}
					
					lastWasElement = true
				} else {
					lastOperator = element
					lastWasElement = false
				}
				
				if n == comparisonsEvaluated.endIndex - 1 {
					if case .value(let finalValue) = lastElement {
						if case .bool(let boolean) = finalValue {
							result = boolean
						}
					}
				}
			}
		} else {
			if case .value(let finalValue) = comparisonsEvaluated[0] {
				if case .bool(let boolean) = finalValue {
					result = boolean
				}
			}
		}
		
		return (result, nil)
	}
	
	init(_ elements: [GBLogicalElement], storage: GBStorage) {
		self.elements = elements
		self.storage = storage
	}
}

enum GBLogicalElement: Equatable {
	static func == (lhs: GBLogicalElement, rhs: GBLogicalElement) -> Bool {
		if case .value(let leftValue) = lhs {
			if case .value(let rightValue) = rhs {
				return leftValue == rightValue
			}
		} else if case .variable(_) = lhs {
			if case .variable(_) = rhs {
				return true
			}
		} else if case .and = lhs {
			if case .and = rhs {
				return true
			}
		} else if case .or = lhs {
			if case .or = rhs {
				return true
			}
		} else if case .equals = lhs {
			if case .equals = rhs {
				return true
			}
		} else if case .lowerThan = lhs {
			if case .lowerThan = rhs {
				return true
			}
		} else if case .higherThan = lhs {
			if case .higherThan = rhs {
				return true
			}
		} else if case .not_equals = lhs {
			if case .not_equals = rhs {
				return true
			}
		}
		
		return false
	}
	
	case and
	case or
	case equals
	case not_equals
	case lowerThan
	case higherThan
	case value(GBValue)
	case variable(String)
}
