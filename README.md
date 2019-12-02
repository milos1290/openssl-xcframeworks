# openssl-xcframeworks

![macOS support](https://img.shields.io/badge/macOS-10.11+-blue.svg)
![iOS support](https://img.shields.io/badge/iOS-11+-blue.svg)
![tvOS support](https://img.shields.io/badge/tvOS-11+-blue.svg)
![watchOS support](https://img.shields.io/badge/watchOS-4.0+-blue.svg)
![macOS Catalyst support](https://img.shields.io/badge/macOS%20Catalyst-10.15+-blue.svg)
![OpenSSL version](https://img.shields.io/badge/OpenSSL-1.1.1d-green.svg)
![OpenSSL version](https://img.shields.io/badge/OpenSSL-1.0.2t-green.svg)
[![license](https://img.shields.io/badge/license-Apache%202.0-lightgrey.svg)](LICENSE)

This is fork of the [OpenSSL-Apple project](https://github.com/keeshux/openssl-apple) by
Davide De Rosa, which is itself a fork of the popular work by
[Felix Schulze](https://github.com/x2on), that is a set of scripts for using self-compiled
builds of the OpenSSL library on the iPhone, Apple TV, Apple Watch, macOS, and Catalyst.

However, this repository branches from Davide's repository by emphasizing support for:

- macOS Catalyst
- building XCFrameworks
- installation via Carthage


# Compile library

Compile OpenSSL 1.0.2t for default archs:

```
./build-libssl.sh --version=1.0.2t
```

Compile OpenSSL 1.1.1d for default targets:

```
./build-libssl.sh --version=1.1.1d
```

Compile OpenSSL 1.0.2d for specific archs:

```
./build-libssl.sh --version=1.0.2d --archs="ios_armv7 ios_arm64 mac_i386"
```

Compile OpenSSL 1.1.1d for specific targets:

```
./build-libssl.sh --version=1.1.1d --targets="ios-cross-armv7 macos64-x86_64"
```

For all options see:

```
./build-libssl.sh --help
```


# Generate frameworks

Statically linked:

```
./create-openssl-framework.sh static
```

Statically linked as XCFramework:

```
./create-openssl-framework.sh xcstatic
```

Dynamically linked:

```
./create-openssl-framework.sh dynamic
```

Dynamically linked as XCFramework:

```
./create-openssl-framework.sh xcdynamic
```


# Use from Carthage


## Carthage notes

Carthage only supports frameworks, and does not support standalone dynamic or static libraries, and
does not currently support XCFrameworks, and so support for all of these is provided by building
these in a fake macOS framework ("OpenSSL-ContainerFramework"), from where you can add whatever you
need to your Xcode project in the usual way. It's kind of a hacky solution, but provides everything
you could need once built or downloaded:

- `$(SRCROOT)/Carthage/Build/Mac/OpenSSL-ContainerFramework.framework/Versions/A/Resources/openssl-xcframeworks/`

  - `framework-dynamic/*/`: Contains an `openssl.framework` for dynamic linking for each platform.
  
  - `framework-static/*/`: Contains an `openssl.framework` for static linking for each platform.
  
  - `xcframework-dynamic/`: Contains the `openssl.xcframework` as a dynamic-linked framework.
  
  - `xcframework-static/`: Contains the `openssl.xcframework` as a static-linked framework.
  
  - `lib/`: Contains static `libcrypto-*.a` and `libssl-*.a` for each platform. These are fat 
    binaries that should cover all current architectures for a platform.

  - `bin/*.sdk/lib/`: Contains static `libcrypto.a` and `libssl.a` for each architecture and
    platform.

Remember, although the `OpenSSL-ContainerFramework.framework` is a macOS project, binaries for
_all_ platforms are in Carthage's `Mac/` build directory.

When Carthage is eventually updated to support XCFrameworks, then the strategy above is likely to
change. 


## Installation (will build from **openssl**'s source)

You can add this repository to your Cartfile as so:

```
github "balthisar/openssl-xcframeworks"
```

Upon issuing `carthage update`, Carthage will download and build the OpenSSL frameworks for each
platform and architecture. This process can be time consuming, but only has to be performed one 
time for each build environment. You can also choose to use the pre-built binaries, next.

As mentioned above, when Carthage is updated to support XCFrameworks, the framework location in the
Carthage build directory is likely to change. You can freeze Carthage to a certain tag or hash in
your Cartfile, if you like.


## Installation (will use binaries that I built)

Other OpenSSL for macOS/iOS distributions tend to distribute binaries in repositories, which seems
to be pretty popular. It's unwise for a couple of reasons:

- You have no idea whether or not the maintainer compiled anything nefarious into the binaries;

- Binaries should not be under version control; they just inflate the repository size.

If you trust my binaries and prefer not to build your own per the previous section (although it's a
one-time requirement only), you can add the following to your Cartfile instead of the repository as
in the previous section:

```
binary "https://raw.githubusercontent.com/balthisar/openssl-xcframeworks/master/OpenSSL-ContainerFramework.json" ~> 1.1.14
```

Upon issuing `carthage update`, the binary framework will be downloaded and unzipped.

Note: the semantic version "1.1.14" corresponds to **openssl**'s version "1.1.1d"; if **openssl**
releases "1.1.1e" then the real semantic version would be "1.1.15", etc. This is required because
Carthage only works with real semantic version numbers.


# Download the Binaries (without Carthage)

You can download and manually manage binaries with the same zip file that Carthage would manage for
you automatically. Take a look at the Github [releases page](https://github.com/balthisar/openssl-xcframeworks/releases)
for this repository.


# Use from Cocoapods

Not currently possible until Cocoapods is updated to work with XCFrameworks.


# Original project

* <https://github.com/x2on/OpenSSL-for-iPhone>


# Davide de Rosa's project

* <https://github.com/keeshux/openssl-apple>


# Acknowledgements

This product includes software developed by the OpenSSL Project for use in the OpenSSL 
Toolkit. (<https://www.openssl.org/>)
