#!/bin/bash

CURRENTDIR=`pwd`
SLIMERDIR=`dirname $0`
SLIMERDIR=`cd $SLIMERDIR;pwd`

XULRUNNER_VERSION="33.1.1"
XULRUNNER_DNL_URL="http://ftp.mozilla.org/pub/mozilla.org/xulrunner/releases/$XULRUNNER_VERSION/runtimes/"
XULRUNNER_PACK_NAME="xulrunner-$XULRUNNER_VERSION.en-US"

cd $SLIMERDIR

BUILD_BIN_PACKAGE="y"
XRDIR=""

usage()
{
    echo "buildpackage.sh [options] [xulrunner-bin-path]"
    echo ""
    echo "options:"
    echo "  --no-bin: don't build binary packages"
    echo "  -h: displays this help"
    echo ""
    echo "xulrunner-bin-path: the path where xulrunner packages can be found"
    echo " or can be stored after downloading them from the mozilla site"
}

for i in $*
do
case $i in
    --no-bin)
    BUILD_BIN_PACKAGE="n"
    ;;
    -h|--help)
        usage
        exit 0
    ;;
    -*)
      echo "ERROR: Unknown option: $i"
      echo ""
      usage
      exit 1
    ;;
    *)
      if [ "$XRDIR" == "" ]; then
          XRDIR=$i
      else
          echo "Warning: no supported parameter. $i ignored"
      fi
    ;;
esac
done

VERSION=`grep "^Version=" src/application.ini`
VERSION=${VERSION:8}

TARGETDIR="$SLIMERDIR/_dist/slimerjs-$VERSION"

if [ "$XRDIR" == "" ]; then
    XRDIR="$SLIMERDIR/_dist/xrbin"
fi

if [ -d "$TARGETDIR" ]
then
    rm -rf $TARGETDIR/*
else
    mkdir -p "$TARGETDIR"
fi

if [ ! -d "$XRDIR" ]
then
    mkdir -p "$XRDIR"
fi


# copy files
cd src

cp application.ini $TARGETDIR
cp slimerjs $TARGETDIR
cp slimerjs.bat $TARGETDIR
cp slimerjs.py $TARGETDIR
cp LICENSE $TARGETDIR
cp README.md $TARGETDIR

# zip chrome files into omni.ja
zip -r $TARGETDIR/omni.ja chrome/ components/ defaults/ modules/ chrome.manifest --exclude @package_exclude.lst

# set the build date
cd $TARGETDIR
BUILDDATE=`date +%Y%m%d`
sed -i -e "s/BuildID=.*/BuildID=$BUILDDATE/g" application.ini

# create the final package
echo "Build the platform independant package..."
cd $SLIMERDIR/_dist
zip -r "slimerjs-$VERSION.zip" "slimerjs-$VERSION"

if [ "$BUILD_BIN_PACKAGE" != "y" ]; then
    # the end
    cd $CURRENTDIR
    echo ""
    echo "slimerjs-$VERSION.zip is in $SLIMERDIR/_dist/"
    exit 0
fi

cd $XRDIR

if [ ! -f "$XRDIR/$XULRUNNER_PACK_NAME.linux-i686.tar.bz2" ]
then
    wget "$XULRUNNER_DNL_URL/$XULRUNNER_PACK_NAME.linux-i686.tar.bz2"
fi
if [ ! -d $XULRUNNER_PACK_NAME.linux-i686 ]; then
    tar xjf "$XULRUNNER_PACK_NAME.linux-i686.tar.bz2"
    mv xulrunner $XULRUNNER_PACK_NAME.linux-i686
fi


if [ ! -f "$XRDIR/$XULRUNNER_PACK_NAME.linux-x86_64.tar.bz2" ]
then
    wget "$XULRUNNER_DNL_URL/$XULRUNNER_PACK_NAME.linux-x86_64.tar.bz2"
fi
if [ ! -d $XULRUNNER_PACK_NAME.linux-x86_64 ]; then
    tar xjf "$XULRUNNER_PACK_NAME.linux-x86_64.tar.bz2"
    mv xulrunner $XULRUNNER_PACK_NAME.linux-x86_64
fi

if [ ! -f "$XRDIR/$XULRUNNER_PACK_NAME.mac.tar.bz2" ]
then
    wget "$XULRUNNER_DNL_URL/$XULRUNNER_PACK_NAME.mac.tar.bz2"
fi
if [ ! -d $XULRUNNER_PACK_NAME.mac ]; then
    tar xjf "$XULRUNNER_PACK_NAME.mac.tar.bz2"
    mv XUL.framework/Versions/Current $XULRUNNER_PACK_NAME.mac
    rm -rf XUL.framework
fi


if [ ! -f "$XRDIR/$XULRUNNER_PACK_NAME.win32.zip" ]
then
    wget "$XULRUNNER_DNL_URL/$XULRUNNER_PACK_NAME.win32.zip"
fi
if [ ! -d $XULRUNNER_PACK_NAME.win32 ]; then
    unzip "$XULRUNNER_PACK_NAME.win32.zip"
    mv xulrunner $XULRUNNER_PACK_NAME.win32
fi

echo "Build linux-i686 package.."
cd $XRDIR
cp -a $XULRUNNER_PACK_NAME.linux-i686 $TARGETDIR/xulrunner
cd $TARGETDIR/..
tar cjf "slimerjs-$VERSION-linux-i686.tar.bz2" "slimerjs-$VERSION"
rm -rf $TARGETDIR/xulrunner

echo "Build linux-x86_64 package..."
cd $XRDIR
cp -a $XULRUNNER_PACK_NAME.linux-x86_64 $TARGETDIR/xulrunner
cd $TARGETDIR/..
tar cjf "slimerjs-$VERSION-linux-x86_64.tar.bz2" "slimerjs-$VERSION"
rm -rf $TARGETDIR/xulrunner

echo "Build MacOS package..."
cd $XRDIR
cp -a $XULRUNNER_PACK_NAME.mac $TARGETDIR/xulrunner
cp $SLIMERDIR/src/macos/Info.plist $TARGETDIR/xulrunner/
cd $TARGETDIR/..
tar cjf "slimerjs-$VERSION-mac.tar.bz2" "slimerjs-$VERSION"
rm -rf $TARGETDIR/xulrunner

echo "Build Windows package..."
# include exec file generated by pyinstaller if it exists
if [ -f $SLIMERDIR/src/slimerjs.exe ]; then
    cp $SLIMERDIR/src/slimerjs.exe $TARGETDIR
else
    if [ -f $SLIMERDIR/src/dist/slimerjs.exe ]; then
        cp $SLIMERDIR/src/dist/slimerjs.exe $TARGETDIR
    fi
fi

cd $XRDIR
cp -a $XULRUNNER_PACK_NAME.win32 $TARGETDIR/xulrunner
cd $TARGETDIR/..
zip -r "slimerjs-$VERSION-win32.zip" "slimerjs-$VERSION"
rm -rf $TARGETDIR/xulrunner

# the end
cd $CURRENTDIR
echo "Packages are in $SLIMERDIR/_dist/"
