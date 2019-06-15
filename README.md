# OfflineRegistry

<a href="https://www.repostatus.org/#active">
<img src="https://www.repostatus.org/badges/latest/active.svg"
alt="Project Status: Active – The project has reached a stable,
usable state and is being actively developed."
/></a> <a
href="https://travis-ci.com/DilumAluthge/OfflineRegistry/branches">
<img
src="https://travis-ci.com/DilumAluthge/OfflineRegistry.svg?branch=master"/>
</a>

# Usage

## Creating the offline registry

```bash
mkdir -p /path/to/desired/location
cd /path/to/desired/location
git clone https://github.com/DilumAluthge/OfflineRegistry
cd OfflineRegistry
export REGISTRY_NAME="MyAwesomeOfflineRegistry"
export REGISTRY_UUID="e8565a5e-8849-4686-8239-e2115313d19d" # Don't use this UUID; generate your own
export GIT_USER_NAME="Myfirstname Mylastname"
export GIT_USER_EMAIL="someone@example.com"
julia make.jl "$REGISTRY_NAME" "$REGISTRY_UUID" "$GIT_USER_NAME" "$GIT_USER_EMAIL"
```

## Using the offline registry

```julia
julia> include("/path/to/desired/location/OfflineRegistry/startup.jl")
julia> include("/path/to/desired/location/OfflineRegistry/default-environment.jl")
julia> import Pkg
julia> Pkg.add(["list", "of", "packages", "to", "add"])
```
