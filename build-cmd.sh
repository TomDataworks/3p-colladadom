#!/bin/sh

# turn on verbose debugging output for parabuild logs.
set -x
# make errors fatal
set -e

if [ -z "$AUTOBUILD" ] ; then 
    fail
fi

COLLADA_VERSION="2.3"

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

echo "${COLLADA_VERSION}" > "${stage}/VERSION.txt"

case "$AUTOBUILD_PLATFORM" in

    windows)
        build_sln "projects/vc12-1.4/dom.sln" "Debug|Win32" domTest
        build_sln "projects/vc12-1.4/dom.sln" "Release|Win32" domTest
        cp -a  "$stage"/packages/lib/debug/icu*.dll build/vc12-1.4-d/
        cp -a  "$stage"/packages/lib/release/icu*.dll build/vc12-1.4/

        # conditionally run unit tests
        if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
            build/vc12-1.4-d/domTest.exe -all
            build/vc12-1.4/domTest.exe -all
        fi

        # stage the good bits
        mkdir -p "$stage"/lib/{debug,release}
        cp -a build/vc12-1.4-d/libcollada14dom23-sd.lib \
            "$stage"/lib/debug/
                
        cp -a build/vc12-1.4/libcollada14dom23-s.lib \
            "$stage"/lib/release/
    ;;

    windows64)
        build_sln "projects/vc12-1.4/dom.sln" "Debug|x64" domTest
        build_sln "projects/vc12-1.4/dom.sln" "Release|x64" domTest
        cp -a  "$stage"/packages/lib/debug/icu*.dll build/vc12-x64-1.4-d/
        cp -a  "$stage"/packages/lib/release/icu*.dll build/vc12-x64-1.4/
        
        # conditionally run unit tests
        if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
            build/vc12-x64-1.4-d/domTest.exe -all
            build/vc12-x64-1.4/domTest.exe -all
        fi

        # stage the good bits
        mkdir -p "$stage"/lib/{debug,release}
        cp -a build/vc12-x64-1.4-d/libcollada14dom23-sd.lib \
            "$stage"/lib/debug/
                
        cp -a build/vc12-x64-1.4/libcollada14dom23-s.lib \
            "$stage"/lib/release/
    ;;

    darwin)
        DEVELOPER="$(xcode-select -print-path)"
        sdk="${DEVELOPER}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.10.sdk"

        # Let's remember to make this universal if we get boost universal again
        opts="${TARGET_OPTS:--arch i386 -arch x86_64 -iwithsysroot $sdk -mmacosx-version-min=10.8 -DMAC_OS_X_VERSION_MIN_REQUIRED=1080}"

        libdir="$top/stage"
        mkdir -p "$libdir"/lib/{debug,release}


        CFLAGS="$opts -gdwarf-2" \
            CXXFLAGS="$opts -gdwarf-2 -std=c++11 -stdlib=libc++" \
            LDFLAGS="-Wl,-headerpad_max_install_names -std=c++11 -stdlib=libc++" \
	    make

        # conditionally run unit tests
        # As of 2014.7.23 tests segfault on mac, disabling completely
#        if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
#            build/mac-1.4-d/domTest -all
#            build/mac-1.4/domTest -all
#        fi

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
            CXXFLAGS="$opts -std=c++11" \
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
    linux64)
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

        # Prefer gcc-4.8 if available.
        if [ -x /usr/bin/gcc-4.8 -a -x /usr/bin/g++-4.8 ]; then
            export CC=/usr/bin/gcc-4.8
            export CXX=/usr/bin/g++-4.8
        fi

        # Default target to 64-bit
        opts="${TARGET_OPTS:--m64}"
        JOBS=`cat /proc/cpuinfo | grep processor | wc -l`
        HARDENED="-fstack-protector-strong -D_FORTIFY_SOURCE=2"

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

        make clean

        LDFLAGS="$opts" \
            CFLAGS="$opts" \
            CXXFLAGS="$opts -std=c++11" \
            make conf=debug -j$JOBS

        LDFLAGS="$opts" \
            CFLAGS="$opts $HARDENED" \
            CXXFLAGS="$opts $HARDENED -std=c++11" \
            make conf=release -j$JOBS

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
cp -a license/tinyxml-license.txt stage/LICENSES/tinyxml.txt

mkdir -p stage/docs/colladadom/
cp -a README.Linden stage/docs/colladadom/

pass

