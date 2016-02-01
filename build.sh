#!/bin/bash

set -xeo pipefail


GD_ENV_FILE=${1:-maza.env}
export GD_OS_PACKAGE=${2}

case ${GD_OS_PACKAGE} in 
linux)
      echo "Building for Linux"
      ;;
  win)
      echo "Building for Windows "
      ;;
  osx)
      echo "Building for OSX"
      ;;
  all)
      echo "Building for Windows Linux and OSX"
      export GD_OS_PACKAGE="osx linux win"
      ;;
    *)
      echo "Usage: ./build.sh [env-file] [win|linux|osx|all]"
      exit 1
      ;;
esac

test -z ${TRAVIS_BUILD_DIR} || export GD_BUILDER=TRAVIS
if [ "${GD_BUILDER}" = "TRAVIS" ]; then 
   echo "GD_BUILDER=TRAVIS" >> ${GD_ENV_FILE} 
fi
export $(cat ${GD_ENV_FILE}  |egrep -v '^#' | xargs)

# get the local UID, and make sure we build the containers 
# with gitian user mapped to this
# ensures write access to output directories
LOCAL_USER=$(whoami)
# TBH I don't know how portable this is, 
# so, we'll bail if we don't have UID
ME=${UID}

function die {
  echo "you do not have a UID=\"${UID}\" set in your environment"
  exit 1
}
test -z ${ME} && die 
if [ "${ME}" = "0" ] ; then
  echo  "Seriously. let's make this run without root privs"
   exit 2
fi
test -f ${GD_HOST_OSXSDK} || exit 3

NAMESPACE=${LOCAL_USER:-gitianbuild}

echo "rm -rf ${NAMESPACE} Stage1 Dockerfile.stage2 Stage2 Dockerfile clean.sh" > ./clean.sh
chmod +x ./clean.sh 

# make a build dir for Docker 
# this prevents Docker context from including 20GB of 
# base-vm files in subsequent runs 
rm -rf Stage1
mkdir Stage1 
cp ${GD_HOST_OSXSDK} Stage1
cp Dockerfile.stage1 Stage1
cp gitian_build.sh Stage1
cp make_gitian_vms.sh Stage1
cp travis_wait.sh Stage1
cp config-lxc Stage1
cp ${GD_ENV_FILE} Stage1
cd Stage1



sed 's/LOCAL_UID/'${ME}'/g' Dockerfile.stage1 > Dockerfile
docker build -f Dockerfile -t ${NAMESPACE}/gitian-stage1 . 
cd ..

mkdir -pv $(pwd)/${NAMESPACE}/gitian-builder/inputs
cp ${GD_HOST_OSXSDK} $(pwd)/${NAMESPACE}/gitian-builder/inputs
mkdir -pv $(pwd)/${NAMESPACE}/gitian-builder/var
mkdir -pv $(pwd)/${NAMESPACE}/${GD_BUILD_COIN}-src
sudo chown -R  ${ME}  $(pwd)/${NAMESPACE}

#docker run -it --rm --privileged --volumes-from gitian_data  ${NAMESPACE}/gitian-stage1
docker run -it --rm --privileged -v $(pwd)/${NAMESPACE}:/data ${NAMESPACE}/gitian-stage1

rm -rf Stage2
mkdir Stage2

echo -e "FROM ${NAMESPACE}/gitian-stage1" > Dockerfile.stage2
echo -e "ENTRYPOINT [\"/gitian/gitian_build.sh\"]" >> Dockerfile.stage2

cp Dockerfile.stage2 Stage2
cd Stage2

docker build -f Dockerfile.stage2 -t ${NAMESPACE}/gitian-builder . 
cd ..
cp ${GD_ENV_FILE} $(pwd)/${NAMESPACE}/gitian-builder
if [ "${GD_BUILDER}" = "TRAVIS" ]; then
   echo "TRAVIS-CI Build Detected....switiching to .travis.yml script"
   echo "docker run -it --rm  --privileged --env-file ${GD_ENV_FILE}  -v $(pwd)/${NAMESPACE}/gitian-builder:/gitian/gitian-builder -v $(pwd)/${NAMESPACE}/${GD_BUILD_COIN}-src:/gitian/${GD_BUILD_COIN}  ${NAMESPACE}/gitian-builder linux-deps" > ./linux-deps.sh
   chmod +x ./linux-deps.sh
   echo "docker run -it --rm  --privileged --env-file ${GD_ENV_FILE}  -v $(pwd)/${NAMESPACE}/gitian-builder:/gitian/gitian-builder -v $(pwd)/${NAMESPACE}/${GD_BUILD_COIN}-src:/gitian/${GD_BUILD_COIN}  ${NAMESPACE}/gitian-builder osx-deps" > ./osx-deps.sh 
   chmod +x ./osx-deps.sh
   echo "docker run -it --rm  --privileged --env-file ${GD_ENV_FILE}  -v $(pwd)/${NAMESPACE}/gitian-builder:/gitian/gitian-builder -v $(pwd)/${NAMESPACE}/${GD_BUILD_COIN}-src:/gitian/${GD_BUILD_COIN}  ${NAMESPACE}/gitian-builder win32-deps" > ./win32-deps.sh
   chmod +x ./win32-deps.sh
   echo "docker run -it --rm  --privileged --env-file ${GD_ENV_FILE}  -v $(pwd)/${NAMESPACE}/gitian-builder:/gitian/gitian-builder -v $(pwd)/${NAMESPACE}/${GD_BUILD_COIN}-src:/gitian/${GD_BUILD_COIN}  ${NAMESPACE}/gitian-builder win64-deps" > ./win64-deps.sh
   chmod +x ./win64-deps.sh
   echo "docker run -it --rm  --privileged --env-file ${GD_ENV_FILE}  -v $(pwd)/${NAMESPACE}/gitian-builder:/gitian/gitian-builder -v $(pwd)/${NAMESPACE}/${GD_BUILD_COIN}-src:/gitian/${GD_BUILD_COIN}  ${NAMESPACE}/gitian-builder linux" > ./linux.sh
   chmod +x ./linux.sh
   echo "docker run -it --rm  --privileged --env-file ${GD_ENV_FILE}  -v $(pwd)/${NAMESPACE}/gitian-builder:/gitian/gitian-builder -v $(pwd)/${NAMESPACE}/${GD_BUILD_COIN}-src:/gitian/${GD_BUILD_COIN}  ${NAMESPACE}/gitian-builder osx" > ./osx.sh 
   chmod +x ./osx.sh
   echo "docker run -it --rm  --privileged --env-file ${GD_ENV_FILE}  -v $(pwd)/${NAMESPACE}/gitian-builder:/gitian/gitian-builder -v $(pwd)/${NAMESPACE}/${GD_BUILD_COIN}-src:/gitian/${GD_BUILD_COIN}  ${NAMESPACE}/gitian-builder win32" > ./win32.sh
   chmod +x ./win32.sh
   echo "docker run -it --rm  --privileged --env-file ${GD_ENV_FILE}  -v $(pwd)/${NAMESPACE}/gitian-builder:/gitian/gitian-builder -v $(pwd)/${NAMESPACE}/${GD_BUILD_COIN}-src:/gitian/${GD_BUILD_COIN}  ${NAMESPACE}/gitian-builder win64" > ./win64.sh
   chmod +x ./win64.sh
   exit 0
fi

for os_pkg in ${GD_OS_PACKAGE} ; do
    docker run -it --rm  --privileged --env-file ${GD_ENV_FILE}  -v $(pwd)/${NAMESPACE}/gitian-builder:/gitian/gitian-builder -v $(pwd)/${NAMESPACE}/${GD_BUILD_COIN}-src:/gitian/${GD_BUILD_COIN}  ${NAMESPACE}/gitian-builder ${GD_OS_PACKAGE}
done

