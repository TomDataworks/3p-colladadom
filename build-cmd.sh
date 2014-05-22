#!/bin/sh

# turn on verbose debugging output for parabuild logs.
set -x
# make errors fatal
set -e

if [ -z "$AUTOBUILD" ] ; then 
    fail
fi

if [ "$OSTYPE" = "cygwin" ] ; then
    export AUTOBUILD="$(cygpath -u $AUTOBUILD)"
fi

#execute build from top-level checkout
cd "$(dirname "$0")"

# load autobuild provided shell functions and variables
set +x
eval "$("$AUTOBUILD" source_environment)"
set -x

top="$(pwd)"
stage="$top/stage"

[ -f "$stage"/packages/include/zlib/zlib.h ] || fail "You haven't installed zlib package yet."

case "$AUTOBUILD_PLATFORM" in

    windows)
        build_sln "projects/vc10-1.4/dom.sln" "Debug|Win32" domTest
        build_sln "projects/vc10-1.4/dom.sln" "Release|Win32" domTest
        
        # conditionally run unit tests
        if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
            build/vc10-1.4-d/domTest.exe -all
            build/vc10-1.4/domTest.exe -all
        fi

        # stage the good bits
        mkdir -p "$stage"/lib/{debug,release}
        cp -a build/vc10-1.4-d/libcollada14dom23-sd.lib \
            "$stage"/lib/debug/
                
        cp -a build/vc10-1.4/libcollada14dom23-s.lib \
            "$stage"/lib/release/
    ;;

    darwin)
        # Darwin build environment at Linden is also pre-polluted like Linux
        # and that affects colladadom builds.
        set

        # Select SDK with full path.  This shouldn't have much effect on this
        # build but adding to establish a consistent pattern.
        #
        # sdk=/Developer/SDKs/MacOSX10.6.sdk/
        # sdk=/Developer/SDKs/MacOSX10.7.sdk/
        # sdk=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.6.sdk/
        sdk=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.7.sdk/
            
        opts="${TARGET_OPTS:--arch i386 -iwithsysroot $sdk -mmacosx-version-min=10.6 -DMAC_OS_X_VERSION_MIN_REQUIRED=1060}"

        libdir="$top/stage"
        mkdir -p "$libdir"/lib/{debug,release}

        make clean arch=i386                            # Hide 'arch' env var

        CFLAGS="$opts -gdwarf-2" \
            CXXFLAGS="$opts -gdwarf-2" \
            LDFLAGS="-Wl,-headerpad_max_install_names" \
            arch=i386 \
            make

        # conditionally run unit tests
        if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
            build/mac-1.4-d/domTest -all
            build/mac-1.4/domTest -all
        fi

        # install_name_tool -id "@executable_path/../Resources/libcollada14dom-d.dylib" "build/mac-1.4-d/libcollada14dom-d.dylib" 
        # install_name_tool -id "@executable_path/../Resources/libcollada14dom.dylib" "build/mac-1.4/libcollada14dom.dylib" 
 
        cp -a build/mac-1.4-d/libcollada14dom-d.a "$libdir"/lib/debug/
        cp -a build/mac-1.4/libcollada14dom.a "$libdir"/lib/release/
    ;;

    linux)
        # Linux build environment at Linden comes pre-polluted with stuff that can
        # seriously damage 3rd-party builds.  Environmental garbage you can expect
        # includes:
        #
        #    DISTCC_POTENTIAL_HOSTS     arch           root        CXXFLAGS
        #    DISTCC_LOCATION            top            branch      CC
        #    DISTCC_HOSTS               build_name     suffix      CXX
        #    LSDISTCC_ARGS              repo           prefix      CFLAGS
        #    cxx_version                AUTOBUILD      SIGN        CPPFLAGS
        #
        # So, clear out bits that shouldn't affect our configure-directed build
        # but which do nonetheless.
        #
        # unset DISTCC_HOSTS CC CXX CFLAGS CPPFLAGS CXXFLAGS

        # Prefer gcc-4.6 if available.
        if [ -x /usr/bin/gcc-4.6 -a -x /usr/bin/g++-4.6 ]; then
            export CC=/usr/bin/gcc-4.6
            export CXX=/usr/bin/g++-4.6
        fi

        # Default target to 32-bit
        opts="${TARGET_OPTS:--m32}"

        # Handle any deliberate platform targeting
        if [ -z "$TARGET_CPPFLAGS" ]; then
            # Remove sysroot contamination from build environment
            unset CPPFLAGS
        else
            # Incorporate special pre-processing flags
            export CPPFLAGS="$TARGET_CPPFLAGS" 
        fi

        libdir="$top/stage"
        mkdir -p "$libdir"/lib/{debug,release}

        make clean arch=i386            # Hide 'arch' env var

        LDFLAGS="$opts" \
            CFLAGS="$opts" \
            CXXFLAGS="$opts" \
            arch=i386 \
            make 

        # conditionally run unit tests
        if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
            build/linux-1.4-d/domTest -all
            build/linux-1.4/domTest -all
        fi

        cp -a build/linux-1.4/libcollada14dom.a "$libdir"/lib/release/
        cp -a build/linux-1.4-d/libcollada14dom-d.a "$libdir"/lib/debug/
    ;;
esac

mkdir -p stage/include/collada
cp -a include/* stage/include/collada

mkdir -p stage/LICENSES
cp -a license.txt stage/LICENSES/collada.txt

mkdir -p stage/LICENSES/collada-other
cp -a license/minizip-license.txt stage/LICENSES/minizip.txt
cp -a license/tinyxml-license.txt stage/LICENSES/tinyxml.txt

mkdir -p stage/docs/colladadom/
cp -a README.Linden stage/docs/colladadom/

pass

