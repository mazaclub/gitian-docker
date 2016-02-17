#!/bin/bash 

GD_OS_PACKAGE=$1
test -z ${GD_OS_PACKAGE} && exit 99

set -xeo pipefail
sudo brctl addbr lxcbr0
sudo ifconfig lxcbr0 10.0.3.1/24 up
sudo service apt-cacher-ng start
sudo service cgmanager start
sudo service cgproxy start
sudo service lxcfs start

GD_BUILD_URL=${GD_BUILD_URL:-https://github.com/mazacoin/mazacoin-new}
GB_BUILD_COIN=${GD_BUILD_COIN:-maza}
GD_BUILD_COMMIT=${GD_BUILD_COMMIT:-master}
GD_BUILD_OSXSDK=${GD_BUILD_OSXSDK:-MacOSX10.9.sdk.tar.gz}

test -d /gitian/gitian-builder/inputs || mkdir /gitian/gitian-builder/inputs
test -f /gitian/gitian-builder/inputs/${GD_BUILD_OSXSDK} || exit 1

cp /etc/hosts /gitian/hosts.orig
echo "10.0.3.5 gitian" >> /gitian/hosts.orig
sudo cp /gitian/hosts.orig /etc/hosts 
sudo chown -R gitian.gitian /gitian 

git clone ${GD_BUILD_URL}  /gitian/${GD_BUILD_COIN} \
  && cd /gitian/${GD_BUILD_COIN}  \
  && git checkout ${GD_BUILD_COMMIT} \
  && cd /gitian/gitian-builder  \
  && make -C ../${GD_BUILD_COIN}/depends download SOURCES_PATH=$(pwd)/cache/common \
  && test -d BINARIES || mkdir -pv /gitian/gitian-builder/BINARIES

if [ "${GD_BUILDER}" = "TRAVIS" ]; then  
   test -f  /gitian/gitian-builder/base-precise-amd64  || cp -av /data/gitian-builder/base-precise-amd64 /gitian/gitian-builder
   echo "TRAVIS BUILD detected"
   ./travis_wait.sh &
fi
for i in ${GD_OS_PACKAGE}
#win linux osx 
  do 
    cd /gitian/gitian-builder
    ./bin/gbuild  --url=../${GD_BUILD_COIN} --commit ${GD_BUILD_COIN}=${GD_BUILD_COMMIT}  ../${GD_BUILD_COIN}/contrib/gitian-descriptors/gitian-${i}.yml 
    mv build/out/ BINARIES/${i} 
    echo "Done building for ${i}"
    echo "Moving your results" 
    test -d results/${i} || mkdir -pv results/${i}
    mv var/* results/${i}/
    mv result/${GD_BUILD_COIN}-${i}* results/${i}/
done

