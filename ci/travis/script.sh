#!/bin/bash

##### Beginning of file

set -ev

export TRAVIS_JULIA_VERSION=$JULIA_VER
echo "TRAVIS_JULIA_VERSION=$TRAVIS_JULIA_VERSION"

export JULIA_FLAGS="--check-bounds=yes --code-coverage=all --color=yes --compiled-modules=yes --inline=no"
echo "JULIA_FLAGS=$JULIA_FLAGS"

export PATH="${PATH}:${TRAVIS_HOME}/julia/bin"

julia $JULIA_FLAGS -e "VERSION >= v\"0.7.0-DEV.3630\" && using InteractiveUtils; versioninfo()"

ls -la $TRAVIS_BUILD_DIR/build || echo "No such file or directory"
cat $TRAVIS_BUILD_DIR/build/* || echo "No such file or directory"

date
rm -rf $HOME/.julia
julia $JULIA_FLAGS $TRAVIS_BUILD_DIR/make.jl "$REGISTRY_NAME" "$REGISTRY_UUID" "$GIT_USER_NAME" "$GIT_USER_EMAIL"
date

ls -la $TRAVIS_BUILD_DIR/build
cat $TRAVIS_BUILD_DIR/build/*

rm -rf $HOME/.julia
julia $JULIA_FLAGS -e '
    include("startup.jl");
    include("default-environment.jl");
    import Pkg;
    Pkg.add("PredictMD");
    Pkg.add("PredictMDExtra");
    Pkg.add("PredictMDFull");
    Pkg.add("DataFrames");
    Pkg.add("StatsBase");
    '

rm -rf $HOME/.julia
julia $JULIA_FLAGS -e '
    include("startup.jl");
    include("default-environment.jl");
    import Pkg;
    Pkg.add(Pkg.PackageSpec(name="PredictMD", rev="master",));
    Pkg.add(Pkg.PackageSpec(name="PredictMDExtra", rev="master",));
    Pkg.add(Pkg.PackageSpec(name="PredictMDFull", rev="master",));
    Pkg.add("DataFrames");
    Pkg.add("StatsBase");
    '

rm -rf $HOME/.julia
julia $JULIA_FLAGS -e '
    include("startup.jl");
    include("default-environment.jl");
    '
julia $JULIA_FLAGS -e '
    include("startup.jl");
    include("default-environment.jl");
    '
julia $JULIA_FLAGS -e '
    include("startup.jl");
    include("default-environment.jl");
    '

julia $JULIA_FLAGS $TRAVIS_BUILD_DIR/clean.jl

##### End of file
