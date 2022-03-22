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

[x] Divide parsing words into different functions

[ ] Divide interpreting tokens into different functions

[ ] Improve code readability (There is a lot of things to improve)

[x] Move GoldByte's core to seperate target for better modularity

[x] Add support for relative paths as arguments

[x] Remove support for top-level code (remember, that use is a macro)

[ ] Improve errors

[ ] Add documentation

[ ] Fix scope issues

# Std library

You can include it by using "use "std"". It uses "arrays", "math" and "strings" libraries.

# Examples

> fullName.goldbyte

use "std"

func getFullName(name:STRING,surname:STRING):STRING {
	var STRING __fullName__ ""
	set $__fullName__ Strings::concat(name,surname)
	return __fullName__
}

func main():NUMBER {
	var STRING name ""
	var STRING surname ""

	@print("Enter your name: ")
	set $name @read()

	@print("Enter your surname: ")
	set $surname @read()

	var STRING fullName ""
	set $fullName getFullName(name,surname)

	@print(fullName)
	return 0
}

> continueUntilFive.goldbyte

use "std"

func main():NUMBER {
	var NUMBER randomNumber 0
	
	while # randomNumber != 5 # {
		set $randomNumber @rand(0,10)
		@println(randomNumber)
	}

	return 0
}

