# GoldByte

# About
GoldByte is a simple programming language that I created. There are many things that can be improved (for example: use of if instead of switch, because after I learned about the first, I forgot about the latter). But after all, it works.

WARNING!
Currently GoldByte is in the early stage of development so many things will change.

# How to build and use?

This package contains 2 targets:
- GoldByte - library containing language
- gbtool - tool to run GoldByte code

1. Install Swift toolchain for your device.

On Mac, you can get it by installing Xcode.
On Fedora Linux, you can install it using sudo dnf install swift.

2. Enter root directory of GoldByte using your terminal.
3. Run swift build -c release.
4. Enter /.build/release at the root of GoldByte's project.
5. Copy or use GoldByte executable.

# How to use?

Run the gbtool executable (can also be placed in CLI's PATH). File's extension must be "goldbyte", but you don't have to write it. For example:

gbtool ~/Desktop/file1.goldbyte
./gbtool /Users/wiktorwojcik/Desktop/file2.goldbyte
./gbtool /Users/wiktorwojcik/Desktop/file3

# To-Do:

[ ] Divide parsing words into different functions

[ ] Divide interpreting tokens into different functions

[ ] Replace many if's with switch

[ ] Improve code readability (There is a lot of things to improve)

[x] Move GoldByte's core to seperate target for better modularity

[x] Add support for relative paths as arguments

[ ] Remove support for top-level code (remember, that use is a macro)

[ ] Improve errors

[ ] Add documentation

# Macros

print <value> - Prints value to console. Must be variable, bool, string, plain text or number.

input <type> <pointer> - Gets a value of specified type from keyboard. Type should be string, number or bool.

ASSIGN <pointer> <value> - Assigns value to variable. Value should be STRING, BOOL, NUMBER, variable, logical expression or equation.

# <logical expression> # - Returns logical operations result. You put it between # signs with 1 space.

<<equation>> - Returns result of equation. You put them between < and > signs without space.

EXIT - Exits program.

RAND <pointer> <number> <number> - Will randomize integer in specified range and assign it to variable.

throw <value> - Exits program with error message. Value should be STRING.

if <logical expression>
 <code block>
}
 
 If statement. Will execute code on code block (between if and }) if logical expression returns true.
 
// - comment. It must be on a seperate line (i.e. Not a the end of line where there is code)

+   -   *   /  - operations

=  <   >    &&     ||    != - logical operators

if # 5 == 6 #

}

Value Types:
NUMBER - number                		234            5564            5.30            -40
STING - string                      "Test"       "ffff"
BOOL - boolean                      true         false         # 5 = 4 #
POINTER - points to variable        $example

func <function name>(<argument name>:<argument value type>,<argument name>:<argument value type>):<return type>
 <code block>
}

Function definition. Function name must be a plain text (i.e. these characters are prohibited: £§!@#$%^&*()+-={}[]|<>?;'\\,./~). Argument name must too be a plain text, and argument value type must be a value type (i.e. NUMBER, STRING (there is support for ANY value type, which makes every value a string, but it may be unexpected)). Return type must be a value type or VOID for no return value. You seperate arguments using , but with no spaces. You end code block using }.

Example:

func getFullName(name:STRING,surname:STRING):STRING
	var STRING fullName ""
	set $fullName Strings::concat(name,surname)
	return fullName
}

# Std library

You can use it by using use "std". It uses "arrays", "math" and "strings" libraries.

# Examples

> fullName.goldbyte

use "std"

func getFullName(name:STRING,surname:STRING):STRING
	var STRING fullName ""
	set $fullName Strings::concat(name,surname)
	return fullName
}

func main():NUMBER
	print getFullName("Wiktor","Wojcik")
	return 0
}
