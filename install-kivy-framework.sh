#!/bin/bash
VERSION=stable
if [ "x$1" != "x" ]; then
VERSION=$1
fi

set -x  # verbose
set -e  # exit on error

SCRIPT_PATH="${BASH_SOURCE[0]}";
PYTHONVER=3.6.1;
PYVER=3.6;
OSXVER=$(sw_vers -productVersion | awk -F '.' '{print $1 "." $2}')
PYTHON=python

if([ -h "${SCRIPT_PATH}" ]) then
while([ -h "${SCRIPT_PATH}" ]) do SCRIPT_PATH=`readlink "${SCRIPT_PATH}"`; done
fi

MACOS_SDK="" #"-mmacosx-version-min=$OSXVER"

SCRIPT_PATH=$(python -c "import os; print(os.path.realpath(os.path.dirname('${SCRIPT_PATH}')))")
OSXRELOCATOR="osxrelocator"
PYPATH="$SCRIPT_PATH/Kivy.app/Contents/Frameworks/python"
PYTHON="$PYPATH/$PYTHONVER/bin/python3"

if [ ! -d cache ]; then
    mkdir cache;
fi;
pushd cache;

if [ -d python3-$PYTHONVER ]; then
    rm -drf python3-$PYTHONVER;
fi;
brew unpack --patch --destdir=. python3;
pushd python3-$PYTHONVER;

OMITVALGRIND=false;
brew list valgrind || OMITVALGRIND=true; #detect valgrind

# -- Build Python in Kivy.app
if [ "$OMITVALGRIND" = false ]; then
    ./configure \
    --prefix=$PYPATH/$PYTHONVER \
    --enable-ipv6 \
    --datarootdir=$PYPATH/$PYTHONVER/share \
    --datadir=$PYPATH/$PYTHONVER/share \
    --enable-shared \
    --with-ensurepip=install \
    --without-gcc \
    --with-valgrind \
    CC=/usr/local/llvm/bin/clang \
    CXX=/usr/local/llvm/bin/clang++ \
    LDFLAGS="$MACOS_SDK -L$(brew --prefix openssl)/lib -L$(brew --prefix sqlite3)/lib" \
    CPPFLAGS="-pipe -w -Os -march=native -isystem/usr/local/include -isystem/usr/include/libxml2 -isystem/System/Library/Frameworks/OpenGL.framework/Versions/Current/Headers -I$(brew --prefix readline)/include -I$(brew --prefix sqlite3)/include -I$(brew --prefix openssl)/include $MACOS_SDK" \
    CFLAGS="-pipe -w -Os -march=native -isystem/usr/local/include -isystem/usr/include/libxml2 -isystem/System/Library/Frameworks/OpenGL.framework/Versions/Current/Headers -I$(brew --prefix readline)/include -I$(brew --prefix sqlite3)/include -I$(brew --prefix openssl)/include $MACOS_SDK" \
    MACOSX_DEPLOYMENT_TARGET=$OSXVER;
else
    ./configure \
    --prefix=$PYPATH/$PYTHONVER \
    --enable-ipv6 \
    --datarootdir=$PYPATH/$PYTHONVER/share \
    --datadir=$PYPATH/$PYTHONVER/share \
    --enable-shared \
    --with-ensurepip=install \
    --without-gcc \
    CC=/usr/local/llvm/bin/clang \
    CXX=/usr/local/llvm/bin/clang++ \
    LDFLAGS="$MACOS_SDK -L$(brew --prefix openssl)/lib -L$(brew --prefix sqlite3)/lib" \
    CPPFLAGS="-pipe -w -Os -march=native -isystem/usr/local/include -isystem/usr/include/libxml2 -isystem/System/Library/Frameworks/OpenGL.framework/Versions/Current/Headers -I$(brew --prefix readline)/include -I$(brew --prefix sqlite3)/include -I$(brew --prefix openssl)/include $MACOS_SDK" \
    CFLAGS="-pipe -w -Os -march=native -isystem/usr/local/include -isystem/usr/include/libxml2 -isystem/System/Library/Frameworks/OpenGL.framework/Versions/Current/Headers -I$(brew --prefix readline)/include -I$(brew --prefix sqlite3)/include -I$(brew --prefix openssl)/include $MACOS_SDK" \
    MACOSX_DEPLOYMENT_TARGET=$OSXVER;
fi;
make VERBOSE=1;
make install PYTHONAPPSDIR=$PYPATH/$PYTHONVER;
if [ -d $PYPATH/$PYTHONVER/lib/static ] ; then
    rm -rf $PYPATH/$PYTHONVER/lib/static;
fi
mkdir $PYPATH/$PYTHONVER/lib/static;
cp libpython${PYVER}m.a $PYPATH/$PYTHONVER/lib/static/libpython${PYVER}m.a;
pushd $PYPATH/$PYTHONVER/bin;
if [ -f python ] ; then
    rm -rf python;
fi
if [ -f pip ] ; then
    rm -rf pip;
#    curl -L -O https://bootstrap.pypa.io/get-pip.py | python
fi;
ln -s python3 python;
ln -s pip3 pip;
ls
./pip install --upgrade pip setuptools;
./pip install wheel;
./pip install nose coverage;
popd; #$PYPATH/$PYTHONVER/bin
popd; #python3-$PYTHONVER

rm -rf $PYPATH/$PYTHONVER/share;
rm -rf $PYPATH/$PYTHONVER/lib/python${PYVER}/{test,unittest/test,turtledemo,tkinter};
chmod -R 644 $PYPATH/$PYTHONVER/include/python${PYVER}m/*
#brew link python3;

# -- Install Boost-Python
BOOSTVER=1.63.0
chmod -R 765 $PYPATH/$PYTHONVER/lib
cp -a /usr/local/Cellar/boost/$BOOSTVER/include/boost $PYPATH/$PYTHONVER/include
cp -a /usr/local/Cellar/boost-python/$BOOSTVER/lib/libboost_python3-mt.dylib $PYPATH/$PYTHONVER/lib/libboost_python3-mt.dylib;
cp -a /usr/local/Cellar/boost-python/$BOOSTVER/lib/libboost_python3.dylib $PYPATH/$PYTHONVER/lib/libboost_python3.dylib;
cp -a /usr/local/Cellar/boost-python/$BOOSTVER/lib/libboost_python3-mt.a $PYPATH/$PYTHONVER/lib/static/libboost_python3-mt.a;
cp -a /usr/local/Cellar/boost-python/$BOOSTVER/lib/libboost_python3.a $PYPATH/$PYTHONVER/lib/static/libboost_python3.a;
chmod -R 755 $PYPATH/$PYTHONVER/lib

# --- Python resources
cp ${SCRIPT_PATH}/data/requirements.txt ${SCRIPT_PATH}/Kivy.app/Contents/Resources/requirements.txt;
pushd ${SCRIPT_PATH}/Kivy.app/Contents/Resources/;

echo "-- Create a virtualenv"
if [ -d venv ] ; then
    rm -rf venv;
fi
$PYTHON -m venv venv;

echo "-- Install dependencies"
source venv/bin/activate
pip install --upgrade pip setuptools;
# pip install wheel;
# pip install cython==0.23 || echo "Skip cython...";
# pip install pygments docutils;
#pip install git+http://github.com/tito/osxrelocator;
#pip install virtualenv;
pip install -r requirements.txt;

echo "-- Link python to the right location for relocation"
if [ -f ./python ] ; then
    rm -rf ./python;
fi
ln -s ./venv/bin/python ./python;
pushd ./venv/bin;
rm python;
ln -s ../../../frameworks/python/$PYTHONVER/bin/python ./python;
popd; #./venv/bin
popd; #${SCRIPT_PATH}/Kivy.app/Contents/Resources/

# --- Kivy

echo "-- Download and compile Kivy"
if [ ! -f $VERSION.zip ] ;then
    curl -O -L https://github.com/kivy/kivy/archive/$VERSION.zip;
fi
cp $VERSION.zip ${SCRIPT_PATH}/Kivy.app/Contents/Resources;
pushd ${SCRIPT_PATH}/Kivy.app/Contents/Resources;
unzip $VERSION.zip;
#rm $VERSION.zip
if [ -d kivy ] ; then
    rm -rf kivy;
fi
mv kivy-$VERSION kivy;
rm -rf $VERSION.zip;

cd kivy;
USE_SDL2=1 CC=/usr/local/bin/clang make;
popd; #${SCRIPT_PATH}/Kivy.app/Contents/Resources

# --- Relocation
echo "-- Relocate frameworks"
pushd ${SCRIPT_PATH}/Kivy.app
osxrelocator -r . /Library/Frameworks/GStreamer.framework/ \
@executable_path/../Frameworks/GStreamer.framework/
osxrelocator -r . /Library/Frameworks/SDL2/ \
@executable_path/../Frameworks/SDL2/
osxrelocator -r . /Library/Frameworks/SDL2_ttf/ \
@executable_path/../Frameworks/SDL2_ttf/
osxrelocator -r . /Library/Frameworks/SDL2_image/ \
@executable_path/../Frameworks/SDL2_image/
osxrelocator -r . @rpath/SDL2.framework/Versions/A/SDL2 \
@executable_path/../Frameworks/SDL2.framework/Versions/A/SDL2
osxrelocator -r . @rpath/SDL2_ttf.framework/Versions/A/SDL2_ttf \
@executable_path/../Frameworks/SDL2_ttf.framework/Versions/A/SDL2_ttf
osxrelocator -r . @rpath/SDL2_image.framework/Versions/A/SDL2_image \
@executable_path/../Frameworks/SDL2_image.framework/Versions/A/SDL2_image
osxrelocator -r . @rpath/SDL2_mixer.framework/Versions/A/SDL2_mixer \
@executable_path/../Frameworks/SDL2_mixer.framework/Versions/A/SDL2_mixer
chmod -R 755 $PYPATH/$PYTHONVER;
osxrelocator -r . $PYPATH/$PYTHONVER \
@executable_path/../Frameworks/python/$PYTHONVER
popd; #${SCRIPT_PATH}/Kivy.app

# relocate the activate script
echo "-- Relocate virtualenv";
pushd ${SCRIPT_PATH}/Kivy.app/Contents/Resources/venv;
virtualenv --relocatable .;
sed -i -r 's#^VIRTUAL_ENV=.*#VIRTUAL_ENV=$(cd $(dirname "$BASH_SOURCE"); dirname `pwd`)#' bin/activate;
rm bin/activate.csh;
rm bin/activate.fish;
popd; #${SCRIPT_PATH}/Kivy.app/Contents/Resources/venv;

pushd ${SCRIPT_PATH}/Kivy.app/Contents/Resources/venv/bin/;
rm ./python3;
rm ./python;
ln -s ../../../frameworks/python/$PYTHONVER/bin/python3 ./python3;
ln -s ../../../frameworks/python/$PYTHONVER/bin/python ./python;

pushd ${SCRIPT_PATH}/Kivy.app/Contents/Resources;
if [ -d .kivy ] ; then
    rm -rf .kivy;
fi
mkdir .kivy;
mkdir .kivy/lib;
mkdir .kivy/include;
ln -s .kivy/lib lib;
ln -s .kivy/include include;
mkdir .kivy/extensions;
mkdir .kivy/extensions/plugins;
mkdir .kivy/mods;
./script -m pip install -r requirements.txt;
popd; #${SCRIPT_PATH}/Kivy.app/Contents/Resources
cp $SCRIPT_PATH/data/config.ini $SCRIPT_PATH/Kivy.app/Contents/Resources/.kivy;
cp /usr/local/llvm/lib/libomp.dylib $SCRIPT_PATH/Kivy.app/Contents/Resources/.kivy/lib/libiomp5.dylib;

pushd $PYPATH/$PYTHONVER;
if [ -d Frameworks ]; then
    rm Frameworks;
fi;
if [ -d Resources ]; then
    rm Resources;
fi;
ln -s ../../../Frameworks Frameworks;
ln -s ../../../Resources Resources;
popd; #$PYPATH/$PYTHONVER

chmod -R 755 $PYPATH/$PYTHONVER;
install_name_tool -id @executable_path/../Frameworks/python/$PYTHONVER/lib/libpython${PYVER}m.dylib $PYPATH/$PYTHONVER/lib/libpython${PYVER}m.dylib;
install_name_tool -id @executable_path/../Frameworks/python/$PYTHONVER/lib/libboost_python3-mt.dylib $PYPATH/$PYTHONVER/lib/libboost_python3-mt.dylib;
install_name_tool -id @executable_path/../Frameworks/python/$PYTHONVER/lib/libboost_python3.dylib $PYPATH/$PYTHONVER/lib/libboost_python3.dylib;
install_name_tool -change $PYPATH/$PYTHONVER/lib/libpython${PYVER}m.dylib @loader_path/../lib/libpython${PYVER}m.dylib $PYPATH/$PYTHONVER/bin/python${PYVER}m;
install_name_tool -change $PYPATH/$PYTHONVER/lib/libpython${PYVER}m.dylib @loader_path/../lib/libpython${PYVER}m.dylib $PYPATH/$PYTHONVER/bin/python${PYVER}m

popd; #${SCRIPT_PATH}/Kivy.app/Contents/Resources/venv/bin/
popd; #cache
echo "-- Done !"
