#!/bin/sh


BUILD_LIBS_DIR=$(cd ${0%/*} && pwd)

export CORE_TOP=${BUILD_LIBS_DIR%/*}
cd $CORE_TOP

CORE_TOP=`pwd`

CURLBIN=`which curl`
if ! test -n "CURLBIN"; then
    display_error "Error: curl is required. Add it to 'PATH'"
    exit 1
fi

GUNZIP=`which gunzip`
UNZIP=`which unzip`
TAR=`which tar`
GNUMAKE=`which gmake`

PATCHES=$CORE_TOP/support/patches
STATICLIBS=$CORE_TOP/libs
DISTDIR=$STATICLIBS/dists

# nspr sources
NSPR_VER=4.9.2
NSPR_DISTNAME=nspr-$NSPR_VER.tar.gz
NSPR_SITE=http://dl.refuge.io

# spidermonkey js sources
JS_VER=185-1.0.0
JS_REALVER=1.8.5
JS_DISTNAME=js$JS_VER.tar.gz
JS_SITE=http://dl.refuge.io
JSDIR=$STATICLIBS/js-$JS_REALVER
JS_LIBDIR=$STATICLIBS/js/lib
JS_INCDIR=$STATICLIBS/js/include

OPENSSL_DISTNAME=guardianproject-openssl-android-327836b.tar.gz
OPENSSL_SITE=http://dl.refuge.io
OPENSSL_DIR=guardianproject-openssl-android-327836b

ERLANG_DISTNAME=otp_src_R15B01.tar.gz
ERLANG_SITE=http://dl.refuge.io
ERLANG_DIR=otp_src_R15B01

ANDROID_NDK_ROOT=/Users/benoitc/android-ndks/android-ndk-r5c
ANDROID_SDK_ROOT=/Users/benoitc/android-sdks
TOOLCHAIN=$CORE_TOP/toolchain



[ "$MACHINE" ] || MACHINE=`(uname -m) 2>/dev/null` || MACHINE="unknown"
[ "$RELEASE" ] || RELEASE=`(uname -r) 2>/dev/null` || RELEASE="unknown"
[ "$SYSTEM" ] || SYSTEM=`(uname -s) 2>/dev/null`  || SYSTEM="unknown"
[ "$BUILD" ] || VERSION=`(uname -v) 2>/dev/null` || VERSION="unknown"


CFLAGS="-mandroid -mthumb "
LDFLAGS="-lstdc++"
ARCH=
ISA64=
GNUMAKE=make
CC=gcc
CXX=g++
case "$SYSTEM" in
    Linux)
        ARCH=`arch 2>/dev/null`
        ;;
    FreeBSD|OpenBSD|NetBSD)
        ARCH=`(uname -p) 2>/dev/null`
        GNUMAKE=gmake
        ;;
    Darwin)
        ARCH=`(uname -p) 2>/dev/null`
        ISA64=`(sysctl -n hw.optional.x86_64) 2>/dev/null`
        ;;
    *)
        ARCH="unknown"
        ;;
esac


# TODO: add mirror & signature validation support
fetch()
{
    TARGET=$DISTDIR/$1
    if ! test -f $TARGET; then
        echo "==> Fetch $1 to $TARGET"
        $CURLBIN --progress-bar -L $2/$1 -o $TARGET
    fi
}


clean_nspr()
{
    rm -rf $STATICLIBS/nspr*
    rm -f $DISTDIR/$NSPR_DISTNAME
}


build_nspr()
{

    fetch $NSPR_DISTNAME $NSPR_SITE

    echo "==> build nspr"
    cd $STATICLIBS
    mkdir -p $STATICLIBS/nsprpub
    $GUNZIP -c $DISTDIR/$NSPR_DISTNAME | $TAR xf -

    cd $STATICLIBS/nspr-$NSPR_VER/mozilla/nsprpub
    ./configure \
        --target=arm-linux-androideabi \
        --with-android-ndk=$ANDROID_NDK_ROOT \
        --with-android-toolchain=$TOOLCHAIN \
        --prefix=$STATICLIBS/nsprpub \
        --enable-strip \
        --disable-debug 
        
    $GNUMAKE all
    $GNUMAKE install 
}

clean_openssl()
{
    rm -rf $STATICLIBS/$OPENSSL_DIR
    rm -f $DISTDIR/$OPENSSL_DISTNAME
}

build_openssl()
{
    fetch $OPENSSL_DISTNAME $OPENSSL_SITE

    cd $STATICLIBS
    $GUNZIP -c $DISTDIR/$OPENSSL_DISTNAME | $TAR -xf -

    echo "==> build openssl"
    cd $OPENSSL_DIR
    $ANDROID_NDK_ROOT/ndk-build
}
    
clean_erlang()
{
    rm -rf $STATICLIBS/$ERLANG_DIR
    #rm -f $DISTDIR/$ERLANG_DISTNAME
}

build_erlang()
{
    echo $PATH
    echo "==> setup Erlang sources"
    #fetch $ERLANG_DISTNAME $ERLANG_SITE

    cd $STATICLIBS
    $GUNZIP -c $DISTDIR/$ERLANG_DISTNAME | $TAR -xf -

    echo `which agcc` 
    echo "==> apply Erlang patches"
    cd $ERLANG_DIR
    for patch in $PATCHES/erlang/*
    do
        patch -p0 -i $patch
    done

    echo "==> build Erlang"
    SKIP=("appmon" "asn1" "common_test" "cosEvent" "cosEventDomain" "cosFileTransfer" "cosNotification" "cosProperty" "cosTime" "cosTransactions" "wx" "debugger" "ssh" "test_server" "toolbar" "odbc" "orber" "reltool" "observer" "dialyzer" "docbuilder" "edoc" "et" "gs" "hipe" "runtime_tools" "percept" "pman" "inviso" "tv" "typer" "webtool" "jinterface" "megaco" "mnesia" "erl_interface" "diameter" "pcre")

    for item in ${SKIP[*]}
    do
        touch "lib/$item/SKIP"
    done


    export ANDROID_SYS_ROOT=$ANDROID_NDK_ROOT
    ./otp_build autoconf
    ./otp_build configure --xcomp-conf=xcomp/erl-xcomp-android.conf --with-ssl=$OPENSSL_DIR
    ./otp_build boot -a
    ./otp_build release -a $STATICLIBS/erlang
}

clean_js()
{
    rm -rf $STATICLIBS/js*
    rm -f $DISTDIR/$JS_DISTNAME
}

build_js()
{

    fetch $JS_DISTNAME $JS_SITE

    mkdir -p $JS_LIBDIR
    mkdir -p $JS_INCDIR

    cd $STATICLIBS
    $GUNZIP -c $DISTDIR/$JS_DISTNAME | $TAR -xf -

    echo "==> build js"
    cd $JSDIR/js/src
    patch -p0 -i $PATCHES/js/patch-jsprf_cpp
	patch -p0 -i $PATCHES/js/patch-configure
    patch -p0 -i $PATCHES/js/patch-js-src-assembler-wtf-Platform_h

    env CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
        CPPFLAGS="-DXP_UNIX -DJS_C_STRINGS_ARE_UTF8 -DFORCE_LITTLE_ENDIAN" \
        CXXFLAGS="-I $TOOLCHAIN/arm-linux-androideabi/include/c++/4.4.3/arm-linux-androideabi" \
        HOST_CXXFLAGS="-DFORCE_LITTLE_ENDIAN" \
        ./configure --prefix=$STATICLIBS/js \
                    --target=arm-android-eabi \
                    --with-android-ndk=$ANDROID_NDK_ROOT \
                    --with-android-toolchain=$TOOLCHAIN \
                    --with-android-sdk=$ANDROID_SDK_ROOT \
	                --with-android-version=8 \
                    --with-arm-kuser \
                    --disable-debug \
					--enable-static \
					--disable-shared-js \
					--disable-tests \
                    --enable-strip \
                    --enable-install-strip \
                    --disable-methodjit \
                    --disable-monoic \
                    --disable-polyic \
                    --disable-pedantic

        $GNUMAKE JS_DISABLE_SHELL=1

    mkdir -p $JS_INCDIR/js
    cp $JSDIR/js/src/*.h $JS_INCDIR
    cp $JSDIR/js/src/*.tbl $JS_INCDIR
    cp $JSDIR/js/src/libjs_static.a $JS_LIBDIR
}



do_setup()
{
    echo "==> couch_core static libs (compile)"
    mkdir -p $DISTDIR

    echo "==> setup toolchain"
    rm -r $TOOLCHAIN || true
    $ANDROID_NDK_ROOT/build/tools/make-standalone-toolchain.sh \
        --platform=android-8 \
        --toolchain=arm-linux-androideabi-4.4.3 \
        --install-dir=$TOOLCHAIN

    # Set up some symlinks to make the SpiderMonkey build system happy
    ln -sf ../platforms $ANDROID_NDK_ROOT/build/platforms
    for f in $TOOLCHAIN/bin/arm-linux-androideabi-*; do
        ln -sf $f ${f/arm-linux-androideabi-/arm-eabi-}
    done

    # Set up some symlinks for the typical autoconf-based build systems
    for f in $TOOLCHAIN/bin/arm-linux-androideabi-*; do
        ln -sf $f ${f/arm-linux-androideabi-/arm-linux-eabi-}
    done
    
    export PATH=$CORE_TOP/support:$CORE_TOP/toolchain/bin:$PATH
}

do_builddeps()
{
#    if [ ! -f $STATICLIBS/nsprpub/lib/libnspr4.a ]; then
#        clean_nspr
#        build_nspr
#    fi

    if [ ! -f $STATICLIBS/js/lib/libjs_static.a ]; then
        clean_js
        build_js
    fi

    if [ ! -f $STATICLIBS/$OPENSSL_DIR/libs/armeabi/libcrypto.so ]; then
        clean_openssl
        build_openssl
    fi

    clean_erlang
    build_erlang
}


clean()
{
#    clean_nspr
    clean_js
    clean_openssl
    clean_erlang
}



usage()
{
    cat << EOF
Usage: $basename [command] [OPTIONS]

The $basename command compile Mozilla Spidermonkey fro emonk.

Commands:

    all:        build couch_core static libs
    clean:      clean static libs
    -?:         display usage

Report bugs at <https://github.com/refuge/couch_core>.
EOF
}



if [ "x$1" = "x" ]; then
    do_setup
    do_builddeps
	exit 0
fi

case "$1" in
    all)
        shift 1
        do_setup
        do_builddeps
        ;;
    clean)
        shift 1
        clean
        ;;
    help|--help|-h|-?)
        usage
        exit 0
        ;;
    *)
        echo $basename: ERROR Unknown command $arg 1>&2
        echo 1>&2
        usage 1>&2
        echo "### $basename: Exitting." 1>&2
        exit 1;
        ;;
esac


exit 0

