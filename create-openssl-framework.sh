#!/bin/bash

set -euo pipefail

# Determine script directory
SCRIPTDIR=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)


# System types we support. Note the matching directories in assets, and that these are
# used as prefixes for many operations of this script.
ALL_SYSTEMS=("iPhone" "AppleTV" "MacOSX" "Watch" "Catalyst")


# Minimum SDK versions to build for
source "${SCRIPTDIR}/scripts/min-sdk-versions.sh"




#
# Output help information.
#
echo_help() {
  cat <<HEREDOC
Usage: $0 [options...] static|xcstatic|dynamic|xcdynamic
Options
     --directory=DIRECTORY         Specify the root build directory where libssl was built. The
                                   default is the script directory.
     --frameworks=DIRECTORY        Specify the directory name to output the finished frameworks,
                                   relative to the root build directory. Default is "frameworks".
Commands
     static                        Build per-platform frameworks meant for static linking.
     xcstatic                      Build an XCFramework meant for static linking.
     dynamic                       Build per-platform frameworks meant for dynamic linking.
     xcdynamic                     Build an XCFramework meant for dynamic linking.
     carthage                      Build the Xcode project via Carthage and Archive it. Really only
                                   useful for the maintainer to prepare the binary version of this
                                   package.
     
The command specified above will build the specified library type based on the targets that were
built with the "build-libssl.sh" script, which must be used first in order to build the object
files.

HEREDOC
}


#
# A nice spinner.
#
spinner() {
  local x=NO
  if [ -o xtrace ]; then
    x=YES
    set +x
  fi
  
  local pid=$!
  local delay=0.75
  local spinstr='|/-\' #\'' (<- fix for some syntax highlighters)
  while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
    local temp=${spinstr#?}
    printf "  [%c]" "$spinstr"
    local spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b\b\b\b\b"
  done

  wait $pid
  if [[ $x == YES ]]; then set -x; fi
  return $?
}


#
# check whether or not bitcode is present in a framework.
#   $1: Path to framework to check.
#
function check_bitcode() {
    local FWDIR=$1

    if [[ $FWTYPE == "dynamic" ]]; then
   		BITCODE_PATTERN="__LLVM"
    else
    	BITCODE_PATTERN="__bitcode"
	fi

	if otool -l "$FWDIR/$FWNAME" | grep "${BITCODE_PATTERN}" >/dev/null; then
       		echo "INFO: $FWDIR contains Bitcode"
	else
        	echo "INFO: $FWDIR doesn't contain Bitcode"
	fi
}


#
# make macos symlinks
#   $1: Path of the framework to check/fix.
#   $2: The system type from ALL_SYSTEMS of the framework.
#
function make_mac_symlinks() {
    local SYSTYPE=$2
    if [[ $SYSTYPE == "MacOSX" ]]; then
		local FWDIR=$1
		local CURRENT=$(pwd)
		cd $FWDIR

		mkdir "Versions"
		mkdir "Versions/A"
		mkdir "Versions/A/Resources"
		mv "openssl" "Headers" "Versions/A"
		mv "Info.plist" "Versions/A/Resources"

		(cd "Versions" && ln -s "A" "Current")
		ln -s "Versions/Current/openssl"
		ln -s "Versions/Current/Headers"
		ln -s "Versions/Current/Resources"
	
		cd $CURRENT
	fi
}


#
# Build a dynamic library for each architecture found in bin, as well as combine the
# individual libraries into a single static library suitable for use in a framework.
#
function build_libraries() {
    DEVELOPER=`xcode-select -print-path`
    FW_EXEC_NAME="${FWNAME}.framework/${FWNAME}"
    INSTALL_NAME="@rpath/${FW_EXEC_NAME}"
    COMPAT_VERSION="1.0.0"
    CURRENT_VERSION="1.0.0"

    RX='([A-z]+)([0-9]+(\.[0-9]+)*)-([A-z0-9]+)\.sdk'

    cd $BUILD_DIR/bin
    
    #
    # build the individual dylibs
    #
    for TARGETDIR in `ls -d *.sdk`; do
        if [[ $TARGETDIR =~ $RX ]]; then
            PLATFORM="${BASH_REMATCH[1]}"
            SDKVERSION="${BASH_REMATCH[2]}"
            ARCH="${BASH_REMATCH[4]}"
        fi
        
        _platform="${PLATFORM}"
        if [[ "${PLATFORM}" == "Catalyst" ]]; then
          _platform="MacOSX"
        fi

        echo "Assembling .dylib and .a for $PLATFORM $SDKVERSION ($ARCH)"

        CROSS_TOP="${DEVELOPER}/Platforms/${_platform}.platform/Developer"
        CROSS_SDK="${_platform}${SDKVERSION}.sdk"
        SDK="${CROSS_TOP}/SDKs/${CROSS_SDK}"

        if [[ $PLATFORM == AppleTVSimulator* ]]; then
            MIN_SDK="-tvos_simulator_version_min $TVOS_MIN_SDK_VERSION"
        elif [[ $PLATFORM == AppleTV* ]]; then
            MIN_SDK="-tvos_version_min $TVOS_MIN_SDK_VERSION"
        elif [[ $PLATFORM == MacOSX* ]]; then
            MIN_SDK="-macosx_version_min $MACOS_MIN_SDK_VERSION"
        elif [[ $PLATFORM == Catalyst* ]]; then
            MIN_SDK="-platform_version mac-catalyst 13.0 $CATALYST_MIN_SDK_VERSION"
        elif [[ $PLATFORM == iPhoneSimulator* ]]; then
            MIN_SDK="-ios_simulator_version_min $IOS_MIN_SDK_VERSION"
        elif [[ $PLATFORM == WatchOS* ]]; then
            MIN_SDK="-watchos_version_min 4.0"
        elif [[ $PLATFORM == WatchSimulator* ]]; then
            MIN_SDK="-watchos_simulator_version_min $WATCHOS_MIN_SDK_VERSION"
        else
            MIN_SDK="-ios_version_min $IOS_MIN_SDK_VERSION"
        fi

        local ISBITCODE=""
        if otool -l "$TARGETDIR/lib/libcrypto.a" | grep "__bitcode" >/dev/null; then
            ISBITCODE="-bitcode_bundle"
        fi
        
        TARGETOBJ="${TARGETDIR}/obj"
        rm -rf $TARGETOBJ
        mkdir $TARGETOBJ
        cd $TARGETOBJ
        ar -x ../lib/libcrypto.a
        ar -x ../lib/libssl.a
        cd ..

        libtool -static -no_warning_for_no_symbols -o ${FWNAME}.a lib/libcrypto.a lib/libssl.a

        ld obj/*.o \
            -dylib \
            $ISBITCODE \
            -lSystem \
            -arch $ARCH \
            $MIN_SDK \
            -syslibroot $SDK \
            -compatibility_version $COMPAT_VERSION \
            -current_version $CURRENT_VERSION \
            -application_extension \
            -o $FWNAME.dylib
        install_name_tool -id $INSTALL_NAME $FWNAME.dylib

        rm -rf obj/
        cd ..
    done
    cd ..
}


#
# build a dynamic framework given the list of targets.
#  $1: a list of targets or directory names for which to build a framework.
#  $2: The system type, needed when passing directory names.
#
build_dynamic_framework() {
    local FWDIR="$1"
    local SYS="$2"
    local FILES=($3)

    echo -e "\nTargets:"
    for target in ${FILES[@]}; do
        if otool -l "$target" | grep "__LLVM" >/dev/null; then
            echo "   $target (contains bitcode)"
        else
            echo "   $target (without bitcode)"
        fi
    done


    if [[ ${#FILES[@]} -gt 0 && -e ${FILES[0]} ]]; then
        printf "Creating dynamic framework for $SYS ($(basename $(dirname $FWDIR)))..."
        mkdir -p $FWDIR/Headers
        lipo -create ${FILES[@]} -output $FWDIR/$FWNAME
        cp -r include/$FWNAME/* $FWDIR/Headers/
        cp -L $SCRIPTDIR/assets/$SYS/Info.plist $FWDIR/Info.plist
        echo -e " done:\n   $FWDIR"
        check_bitcode $FWDIR
        make_mac_symlinks $FWDIR $SYS
    else
        echo "Skipped framework for $SYS"
    fi
}


#
# build static frameworks given the list of targets.
#  $1: Output directory for the framework.
#  $2: System type of the framework.
#  $3: List of library files to embed in the framework.
#
build_static_framework() {
    local FWDIR="$1"
    local SYS="$2"
    local FILES=($3)

    echo -e "\nCreating static framework for $SYS"
    for FILE in ${FILES[@]}; do
        if otool -l "$FILE" | grep "__bitcode" >/dev/null; then
            echo "   $FILE (contains bitcode)"
        else
            echo "   $FILE (without bitcode)"
        fi
    done
    mkdir -p $FWDIR/Headers
    
    # Don't lipo single files.
    if [[ ${#FILES[@]} -gt 1 ]]; then
        lipo -create ${FILES[@]} -output $FWDIR/$FWNAME
    else
        cp ${FILES[0]} $FWDIR/$FWNAME
    fi
    
    cp -r include/$FWNAME/* $FWDIR/Headers/
    cp -L $SCRIPTDIR/assets/$SYS/Info.plist $FWDIR/Info.plist
    echo "Created $FWDIR"
    check_bitcode $FWDIR
    make_mac_symlinks $FWDIR $SYS
}


#
# build an XCFramework in the frameworks directory, with the assumption that the 
# individual, desired architecture frameworks are already present.
#
build_xcframework() {
    local FRAMEWORKS=($BUILD_DIR/$FWROOT/*/$FWNAME.framework)
    local ARGS=
    for ARG in ${FRAMEWORKS[@]}; do
        ARGS+="-framework ${ARG} "
    done
    
    echo
    xcodebuild -create-xcframework $ARGS -output "$BUILD_DIR/$FWROOT/$FWNAME.xcframework"

    # These intermediate frameworks are silly, and not needed any more.
    find ${FWROOT} -mindepth 1 -maxdepth 1 -type d -not -name "$FWNAME.xcframework" -exec rm -rf '{}' \;
}


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

