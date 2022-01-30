# Getting started

## Intalling gbtool - CLI for working with GoldByte
### by downloading prebuilt tool (not recommended)
Download the newest release from Github at https://github.com/wiktorwojcik112/GoldByte/releases.
Remember that there are currently only releases for macOS.

### by building from source (recommended)
1. Download Swift toolchain by following "Installing Swift" section on https://www.swift.org/getting-started/.
2. Clone GoldByte repository: git clone https://github.com/wiktorwojcik112/GoldByte.git
3. Enter GoldByte directory: cd GoldByte
4. Build using Swift: swift build -c release
5. After building, enter .build/release directory: cd .build/release
6. Run ./gbtool link. This will create a symlink to gbtool at that path in /usr/local/bin.
7. Now you can use gbtool.

