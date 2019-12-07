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

- builds XCFrameworks (hence the repository name) with truly universal libraries. With Xcode 11
  and newer, XCFrameworks offer a single package with frameworks for every, single Apple
  architecture. You no longer have to use run script build phases to slice and dice binary files;
  Xcode will choose the right framework for the given target.

- Supports all of the xcode $STANDARD_ARCHS by default for each Apple platform. This means that
  the frameworks work with your Xcode project right out of the box, with no fussing about with
  VALID_ARCHITECTURES, etc. It's tempting to leave old architectures (armv7, for example) behind,
  but Apple still seems to expect them.

- Builds traditional dynamic or static platform-specific frameworks, should that be your cup of
  tea.

- Builds traditional dylibs or static libraries (libcrypto.{dylib,a}, libssl.{dylib,a}), should
  that be your preferred poison.

- Supports installation via Carthage via the use of a fake framework.

- Supports OpenSSL-1.1.1d and newer. It might work with version 1.1.0, but testing begins with
  1.1.1d. Versions prior to 1.1.0 are definitely *not* supported. This is a forward-thinking
  distribution; it's time to bite the bullet and update to the new API's.


# What's Built

The `build-openssl.sh` script builds per-platform static libraries `libcrypto.a` and `libssl.a`;
if you've built multiple architectures for a platform (which is default), then these static
libraries will be fat binaries consisting of all architectures that were built.

Additionally, the per-architecture static libraries are also available, but these are generally
not useful to most programmers.

Dynamic libraries (.dylibs) have generally fallen out of favor on macOS, and are not built. You
should use frameworks instead.

The `create-framework.sh` script builds frameworks, which are the preferred and simplest forms
of library integration. Standard per-platform dynamic frameworks will be built, but
per-platform static frameworks can also be built. This latter option isn't a framework per se,
but a convenient means of distribution.

The script also builds both dynamic and static XCFrameworks, which are new in Xcode 11 and newer,
and easily allow you to integrate _all_ platforms and architectures in a single distributable.


# Compile library


Compile OpenSSL at the default version (currently 1.1.1d) for default targets:

```
./build-openssl.sh
```

Compile OpenSSL at the default version for specific targets:

```
./build-openssl.sh --version=1.1.1d --targets="ios-cross-armv7 macos64-x86_64"
```

For all options see:

```
./build-openssl.sh --help
```


# Generate frameworks

Statically linked:

```
./create-framework.sh static
```

Statically linked as XCFramework:

```
./create-framework.sh xcstatic
```

Dynamically linked:

```
./create-framework.sh dynamic
```

Dynamically linked as XCFramework:

```
./create-framework.sh xcdynamic
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
