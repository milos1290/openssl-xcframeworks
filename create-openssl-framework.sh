#!/bin/bash

set -euo pipefail

# Determine script directory
SCRIPTDIR=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)


# System types we support. Note the matching directories in assets, and that these are
# used as prefixes for many operations of this script.
ALL_SYSTEMS=("iPhone" "AppleTV" "MacOSX" "Watch" "Catalyst")


# Bring in libraries.
source "${SCRIPTDIR}/scripts/lib-min-sdk-versions.sh"
source "${SCRIPTDIR}/scripts/lib-frameworks.sh"
source "${SCRIPTDIR}/scripts/lib-spinner.sh"


#
# main
#

# Defaults, some of which will be overridden by CLI args.
BUILD_DIR="$SCRIPTDIR" # Where the built libraries are.
FWROOT="frameworks"    # Containing directory within the build directory.
FWNAME="openssl"       # Name of the finished framework.
COMMAND=""             # Command specified on CLI.
FWXC=NO                # building an XCFramework?
FWTYPE=""              # Static or Dynamic?

# Process command line arguments
for i in "$@"; do
    case $i in
      --directory=*)
        BUILD_DIR="${i#*=}"
        BUILD_DIR="${BUILD_DIR/#\~/$HOME}"
        shift
        ;;
      --frameworks=*)
        FWROOT="${i#*=}"
        FWROOT="${FWROOT/#\~/$HOME}"
        shift
        ;;
      carthage)
        (carthage build --configuration Release --no-use-binaries --no-skip-current  --project-directory .) & spinner
        (carthage archive) & spinner
        exit
        ;;
      static|xcstatic|dynamic|xcdynamic)
        if [[ ! -z $COMMAND ]]; then
            echo "Only one command can be specified, and you've already provided '$COMMAND'."
            echo "Therefore ignoring '$i' and any subsequent commands you might have provided."
        else
            COMMAND=$i
            FWTYPE=$i
            if [[ $FWTYPE == xc* ]]; then
                FWXC=YES
                FWTYPE=${FWTYPE:2}
            fi
        fi   
        ;;
      -h|--help)
        echo_help
        exit
        ;;
      *)
        echo "Unknown argument: ${i}"
        ;;
    esac
done

# A command is required.
if [[ -z $COMMAND ]]; then
    echo_help
    exit
fi

# Make sure the library was built first.
if [ ! -d "${BUILD_DIR}/lib" ]; then
    echo "Please run build-libssl.sh first!"
    exit 1
fi

# Clean up previous
if [ -d "${BUILD_DIR}/${FWROOT}" ]; then
    echo "Removing previous $FWNAME.framework copies"
    rm -rf "${BUILD_DIR}/${FWROOT}"
fi


# Perform the build.

cd $BUILD_DIR
build_libraries

if [ $FWTYPE == "dynamic" ]; then

	if [[ $FWXC == NO ]]; then
		# create per platform frameworks, which might be all a developer needs.
		for SYS in ${ALL_SYSTEMS[@]}; do
		    FWDIR="$BUILD_DIR/$FWROOT/$SYS/$FWNAME.framework"
            FILES=($BUILD_DIR/bin/${SYS}*/$FWNAME.dylib)
    		build_dynamic_framework $FWDIR $SYS "${FILES[*]}"
    	done

    else
		# Create per destination frameworks, which will be combined into a single XCFramework.
		# xcodebuild -create-xcframework only works with per destination frameworks, e.g.,
		# iOS devices, tvOS simulator, etc., which must already have fat libraries for the
		# architectures.
		for SYS in ${ALL_SYSTEMS[@]}; do
			cd $BUILD_DIR/bin
			ALL_TARGETS=(${SYS}*)
			TARGETS=$(for TARGET in ${ALL_TARGETS[@]}; do echo "${TARGET%-*}"; done | sort -u)
			cd ..
			for TARGET in ${TARGETS[@]}; do		
                FWDIR="$BUILD_DIR/$FWROOT/$TARGET/$FWNAME.framework"
                FILES=($BUILD_DIR/bin/${TARGET}*/$FWNAME.dylib)
                build_dynamic_framework $FWDIR $SYS "${FILES[*]}"
            done
		done

		build_xcframework		
    fi
    
else

	if [[ $FWXC == NO ]]; then
		# create per platform frameworks, which might be all a developer needs.
        for SYS in ${ALL_SYSTEMS[@]}; do
            FWDIR="$BUILD_DIR/$FWROOT/$SYS/$FWNAME.framework"
            FILES=($BUILD_DIR/bin/${SYS}*/${FWNAME}.a)
            build_static_framework $FWDIR $SYS "${FILES[*]}"
        done    
    else
		# Create per destination frameworks, which will be combined into a single XCFramework.
		for SYS in ${ALL_SYSTEMS[@]}; do
			cd $BUILD_DIR/bin
			ALL_TARGETS=(${SYS}*)
			TARGETS=$(for TARGET in ${ALL_TARGETS[@]}; do echo "${TARGET%-*}"; done | sort -u)
			cd ..
			for TARGET in ${TARGETS[@]}; do
                FWDIR="$BUILD_DIR/$FWROOT/$TARGET/$FWNAME.framework"
                FILES=($BUILD_DIR/bin/${TARGET}*/${FWNAME}.a)
                build_static_framework $FWDIR $SYS "${FILES[*]}"
            done
		done

		build_xcframework
    fi
fi

# The built libraries aren't required any longer.
rm $BUILD_DIR/bin/*/$FWNAME.{dylib,a}

