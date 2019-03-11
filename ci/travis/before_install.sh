#!/bin/bash

##### Beginning of file

set -ev

export TRAVIS_JULIA_VERSION=$JULIA_VER
echo "TRAVIS_JULIA_VERSION=$TRAVIS_JULIA_VERSION"

export JULIA_FLAGS="--check-bounds=yes --code-coverage=all --color=yes --compiled-modules=yes --inline=no"
echo "JULIA_FLAGS=$JULIA_FLAGS"

if [[ "$TRAVIS_OS_NAME" == "linux" ]];
then
    if [[ "$TRAVIS_JULIA_VERSION" == "1.1" ]];
    then
        export JULIA_URL="https://julialang-s3.julialang.org/bin/linux/x64/1.1/julia-1.1-latest-linux-x86_64.tar.gz"
    else
        true
    fi

    cd $HOME
    export CURL_USER_AGENT="Travis-CI $(curl --version | head -n 1)"
    mkdir -p ~/julia
    curl -A "$CURL_USER_AGENT" -s -L --retry 7 "$JULIA_URL" | tar -C ~/julia -x -z --strip-components=1 -f -
else
    true
fi

if [[ "$TRAVIS_OS_NAME" == "osx" ]];
then
    if [[ "$TRAVIS_JULIA_VERSION" == "1.1" ]];
    then
        export JULIA_URL="https://julialang-s3.julialang.org/bin/mac/x64/1.1/julia-1.1-latest-mac64.dmg"
    else
        true
    fi

    cd $HOME
    export CURL_USER_AGENT="Travis-CI $(curl --version | head -n 1)"
    curl -A "$CURL_USER_AGENT" -s -L --retry 7 -o julia.dmg "$JULIA_URL"
    mkdir juliamnt
    hdiutil mount -readonly -mountpoint juliamnt julia.dmg
    cp -a juliamnt/*.app/Contents/Resources/julia ~/
else
    true
fi

export PATH="${PATH}:${TRAVIS_HOME}/julia/bin"

julia $JULIA_FLAGS -e "VERSION >= v\"0.7.0-DEV.3630\" && using InteractiveUtils; versioninfo()"

##### End of file
