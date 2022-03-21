//
//  GBCalculator.swift
//  GoldByte
//
//  Created by Wiktor Wójcik on 24/11/2021.
//

import Foundation

struct GBEquation {
	var equation: [GBEquationSymbol]
	var storage: GBStorage
	
	init(_ equation: [GBEquationSymbol], storage: GBStorage) {
		self.equation = equation
		self.storage = storage
	}
	
	enum Level {
		case DivideAndMultiply
		case PlusAndMinus
	}
	
	func getVariables(_ equation: [GBEquationSymbol]) -> ([GBEquationSymbol]?, GBError?) {
		var copy = equation
		
		for (n, symbol) in equation.enumerated() {
			if case .variable(let key) = symbol {
				let variable = storage[key]
				
				if variable.type != .number {
					return (nil, .init(type: .panic, description: "Variable \"\(key)\" is not a number."))
				}
				
				copy[n] = .number(Float(variable.value)!)
			}
		}
		
		return (copy, nil)
	}
	
	func evaluate() -> (Float?, GBError?) {
		let (withoutVariables, error) = getVariables(equation)
		if let error = error {
			return (nil, error)
		}
		
		var result: Float = -1
		
		var equation = withoutVariables!
		
		var lastOperator: GBOperator? = nil
		
		for symbol in equation {
			if result == -1 {
				if case .number(let number) = symbol {
					result = number
				}
			} else if lastOperator == nil {
				lastOperator = symbol.toOperator()
			} else {
				var currentNumber: Float = 0
				
				if case .number(let number) = symbol {
					currentNumber = number
				}
					
				switch lastOperator! {
					case .plus:
						result += currentNumber
					case .minus:
						result -= currentNumber
					case .multiply:
						result *= currentNumber
					case .divide:
						if currentNumber != 0 {
							result /= currentNumber
						} else {
							return (nil, .init(type: .panic, description: "Can't divide by 0."))
						}
				}
				
				lastOperator = nil
			}
		}

		return (result, nil)
	}
}

enum GBEquationSymbol: Equatable {
	case number(Float)
	case variable(String)
	case plus
	case minus
	case divide
	case multiply
	
	func toOperator() -> GBOperator? {
		switch self {
			case .plus:
				return .plus
			case .minus:
				return .minus
			case .divide:
				return .divide
			case .multiply:
				return .multiply
			default:
				return nil
		}
	}
}

enum GBOperator {
	case plus
	case minus
	case divide
	case multiply
	
	func toSymbol() -> GBEquationSymbol {
		switch self {
			case .plus:
				return .plus
			case .minus:
				return .minus
			case .divide:
				return .divide
			case .multiply:
				return .multiply
		}
	}
}
