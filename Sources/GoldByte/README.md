#GoldByte

GoldByte is an language which allows creating simple programs. GoldByte can also be used as connection between different languages. It is compiled into Low GoldByte Code (no abstraction) and then interpreted.

GoldByte is also modular.

Commands:

PRINT <value> - Prints value to console. Must be variable, bool, string, plain text or number.

INPUT <type> <pointer> - Gets a value of specified type from keyboard. Type should be string, number or bool.

ASSIGN <pointer> <value> - Assigns value to variable. Value should be STRING, BOOL, NUMBER, variable, logical expression or equation.

# <logical expression> # - Returns logical operations result. You put it between # signs with 1 space.

<<equation>> - Returns result of equation. You put them between < and > signs without space.

EXIT - Exits program.

RAND <pointer> <number> <number> - Will randomize integer in specified range and assign it to variable.

ERROR <value> - Exits program with error message. Value should be STRING.

JUMP <line key> <condition (optional)> - Jumps to line with specified line key. If there is condition, jump will be performed if logical expression returns true. Line key should be STRING.

<line key>:<macro> - You assign line key to line by prefixing first word of line with plain text key without special characters and putting : next to it and next to : macro. All without spaces. Doesn't work in code block, for example in IF.

 IF <logical expression> - If statement. Will execute code on code block (between IF and /IF) if logical expression returns true.
 <code block>
 /IF
 
// - comment

+   -   *   /  - operations

=  <   >    &&     ||    != - logical operators

IF # 5 == 6 #

/IF

EMBED[<language>]: - embeds language code. Supports C, Swift and JavaScript.
GoldByte compiles code, and runs code using launch arguments (ex. argv). GoldByte will convert
All mentions of variables in code with appropriate argv index.
You can put code in $[] to put code outside int main().

EMBED(c):
$[include <iostream>]
$[using namespace std;]

cout << "test" << endl;
/EMBED


Macro is a Swift code that can be executed from Swift. You declare it in the source code.


Value Types:
NUMBER - number                		234            5564            5.30            -40
STING - string                      "Test"       "ffff"
BOOL - boolean                      true         false         # 5 = 4 #
ARRAY - collection                  [5 | "test" | false]
POINTER - points to variable        $example


> main.goldybte

PRINT "Hello, world"


> calculate.goldbyte

VAR NUMBER a 0
VAR NUMBER b 0
PRINT "Podaj liczbe a:"
INPUT number $a
PRINT "Podaj liczbę b:"
INPUT number $b
VAR NUMBER result 0
VAR STRING operator ""
PRINT "Podaj operator (+ - * /):"
INPUT string $operator
IF # operator == "+" #
ASSIGN $result <a + b>
PRINT result
EXIT
/IF
IF # operator == "*" #
ASSIGN $result <a * b>
PRINT result
EXIT
/IF
IF # operator == "-" #
ASSIGN $result <a - b>
PRINT result
EXIT
/IF
IF # b == 0 #
PRINT "Can't divide by 0"
EXIT
/IF
ASSIGN $result <a / b>
PRINT result
