# GoldByte

# About
GoldByte is a simple programming language that I created. There are many things that could be improved (for example: use of if let instead of switch, because after I learned about the first, I forgot about the latter). But after all, it works.

# How to build?

1. Install Swift toolchain for your device.

On Mac, you can get it by installing Xcode.
On Fedora Linux, you can install it using sudo dnf install swift.

2. Enter root directory of GoldByte using your terminal.
3. Run swift build -c release.
4. Enter /.build/release at the root of GoldByte's project.
5. Copy or use GoldByte executable.

# How to use?

Run the GoldByte executable (can also be placed in CLI's PATH) with the absolute path or with tilde (~). File's extension must be goldbyte. For example:

GoldByte ~/Desktop/file1.goldbyte
./GoldByte /Users/wiktorwojcik/Desktop/file2.goldbyte

# To-Do:

[ ] Replace many if let's with switch
[ ] Improve code readability
[ ] Move GoldByte's core to seperate target for better modularity
[ ] Add support for relative paths as arguments
[ ] Remove support for top-level code (remember, that USE is a macro)
[ ] Improve errors
[ ] Add documentation

# Macros

PRINT <value> - Prints value to console. Must be variable, bool, string, plain text or number.

INPUT <type> <pointer> - Gets a value of specified type from keyboard. Type should be string, number or bool.

ASSIGN <pointer> <value> - Assigns value to variable. Value should be STRING, BOOL, NUMBER, variable, logical expression or equation.

# <logical expression> # - Returns logical operations result. You put it between # signs with 1 space.

<<equation>> - Returns result of equation. You put them between < and > signs without space.

EXIT - Exits program.

RAND <pointer> <number> <number> - Will randomize integer in specified range and assign it to variable.

ERROR <value> - Exits program with error message. Value should be STRING.

IF <logical expression>
 <code block>
/IF
 
 If statement. Will execute code on code block (between IF and /IF) if logical expression returns true.
 
// - comment. It must be on a seperate line (i.e. Not a the end of line where there is code)

+   -   *   /  - operations

=  <   >    &&     ||    != - logical operators

IF # 5 == 6 #

/IF

Value Types:
NUMBER - number                		234            5564            5.30            -40
STING - string                      "Test"       "ffff"
BOOL - boolean                      true         false         # 5 = 4 #
POINTER - points to variable        $example

FN <function name>(<argument name>:<argument value type>,<argument name>:<argument value type>):<return type>
 <code block>
/FN

Function definition. Function name must be a plain text (i.e. these characters are prohibited: £§!@#$%^&*()+-={}[]|<>?;'\\,./~). Argument name must too be a plain text, and argument value type must be a value type (i.e. NUMBER, STRING (there is support for ANY value type, which makes every value a string, but it may be unexpected)). Return type must be a value type or VOID for no return value. You seperate arguments using , but with no spaces. You end code block using /FN.

Example:

FN getFullName(name:STRING,surname:STRING):STRING
	VAR STRING fullName ""
	ASSIGN $fullName Strings::concat(name,surname)
	RETURN fullName
/FN

# Std library

You can use it by using USE "std". It uses "arrays", "math" and "strings" libraries.

# Examples

> fullName.goldbyte

USE "std"

FN getFullName(name:STRING,surname:STRING):STRING
	VAR STRING fullName ""
	ASSIGN $fullName Strings::concat(name,surname)
	RETURN fullName
/FN

FN main():NUMBER
	PRINT getFullName("Wiktor","Wojcik")
	RETURN 0
/FN
