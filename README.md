# toolchain to build couchdb/rcouch on android

Toolchain replacing the couchbase one to build couchdb and rcouch on
android.

This toolchain allows to use android-sdk/android-ndk on all the platform
supported by the Android tookchain and bump the erlang version to
R15b01. It is also building spidermonkey 1.8.5 .


## REQUIREMENTS

- Android NDK rc5c
- Android SDK 8 

## Setup environment

Get the sources and install somewhere the android sdk and ndk and edit
the variables `ANDROID_NDK_ROOT` and `ANDROID_SDK_ROOT` in
`support/build_libs.sh` to point to them.

> TODO: make this part automatic

## Build libs

    $ cd build-android
    $ ./support/build_libs.sh
