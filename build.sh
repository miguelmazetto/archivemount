#!/bin/bash

SDIR=$PWD

export NDK_PKG=/home/mmz/.ndk-pkg
export NDK_TOOLCHAIN=/home/mmz/dev/ndk
export TOOLCHAIN=$NDK_TOOLCHAIN/toolchains/llvm/prebuilt/linux-x86_64
export ANDROID_USR=$TOOLCHAIN/sysroot/usr
export FUSE_SDIR=$SDIR/libfuse-2.9.9
export LIBARCHIVE_DIR=$NDK_PKG/install.d/android/21/libarchive
export LIBICONV_DIR=$NDK_PKG/install.d/android/21/libiconv
export API=24 # Set this to your minSdkVersion.

rm -rf $SDIR/jniLibs
mkdir $SDIR/jniLibs

copylib_ndkpkg(){ # pkgname libfile
	cp -f "$NDK_PKG/install.d/android/21/$1/$JNIOUT/lib/$2" "$JNIOUTDIR/$2"
}

configure_android(){
	export JNIOUTDIR=$SDIR/jniLibs/$JNIOUT
	mkdir $JNIOUTDIR
	export CFLAGS="-I$ANDROID_USR/include"
	export LDFLAGS="-R$ANDROID_USR/lib/$TARGET/$API -L$ANDROID_USR/lib/$TARGET/$API -L$JNIOUTDIR"
	export AR=$TOOLCHAIN/bin/llvm-ar
	export CC=$TOOLCHAIN/bin/$TARGET$API-clang
	export AS=$CC
	export CXX=$TOOLCHAIN/bin/$TARGET$API-clang++
	export LD=$TOOLCHAIN/bin/ld
	export RANLIB=$TOOLCHAIN/bin/llvm-ranlib
	export STRIP=$TOOLCHAIN/bin/llvm-strip
}

greencol=$(tput setaf 46)
defaultcol=$(tput sgr0)

backup_flags(){
	BCK_CFLAGS=$CFLAGS
	BCK_LDFLAGS=$LDFLAGS
}
modflags_archivemount(){
	backup_flags
	export CFLAGS="$CFLAGS -I$FUSE_SDIR/include -I$LIBARCHIVE_DIR/$JNIOUT/include"
	export LDFLAGS="$LDFLAGS -lfuse -larchive"
}
restore_flags(){
	export CFLAGS=$BCK_CFLAGS
	export LDFLAGS=$BCK_LDFLAGS
}

goto_build(){
	mkdir -p build/$JNIOUT;	cd build/$JNIOUT
}

configure_libfuse(){
	cd $FUSE_SDIR; goto_build
	../../configure --host $TARGET --disable-mtab --enable-example=no
}

compile_libfuse(){
	printf "\n${greencol}Compiling libfuse2 for $TARGET...\n\n${defaultcol}"

	configure_libfuse
	make -j

	cp -f lib/.libs/libfuse.so $JNIOUTDIR/libfuse.so
}

configure_archivemount(){
	cd $SDIR; goto_build
	copylib_ndkpkg libarchive libarchive.so
	copylib_ndkpkg libiconv libiconv.so
	copylib_ndkpkg libiconv libcharset.so
	copylib_ndkpkg openssl libcrypto.so.1.1
	copylib_ndkpkg lzo liblzo2.so
	copylib_ndkpkg lz4 liblz4.so.1
	copylib_ndkpkg bzip2 libbz2.so
	copylib_ndkpkg zstd libz.so
	copylib_ndkpkg xz liblzma.so
	cp -f $LIBARCHIVE_DIR/$JNIOUT/lib/libarchive.so $JNIOUTDIR/libarchive.so
	cp -f $LIBICONV_DIR/$JNIOUT/lib/libiconv.so $JNIOUTDIR/libiconv.so
	cp -f $LIBICONV_DIR/$JNIOUT/lib/libcharset.so $JNIOUTDIR/libcharset.so
	cp -f $LIBICONV_DIR/$JNIOUT/lib/libiconv.so $JNIOUTDIR/libiconv.so
	modflags_archivemount
	../../configure --host $TARGET
}

compile_archivemount(){
	printf "\n${greencol}Compiling archivemount for $TARGET...\n\n${defaultcol}"

	configure_archivemount
	make -j

	cp -f ./archivemount $JNIOUTDIR/libarchivemount.so
}

doall(){
	configure_android

	compile_libfuse
	compile_archivemount
}

# autoconf
cd $FUSE_SDIR; ./makeconf.sh
cd $SDIR; autoreconf -i

export TARGET=aarch64-linux-android
JNIOUT=arm64-v8a
doall

export TARGET=x86_64-linux-android
JNIOUT=x86_64
doall

export TARGET=armv7a-linux-androideabi
JNIOUT=armeabi-v7a
doall

printf "\nDone!\n\n"

cd $SDIR