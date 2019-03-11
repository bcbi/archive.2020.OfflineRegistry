import Pkg

pushfirst!(Base.DEPOT_PATH,joinpath(splitpath(@__DIR__)..., "depot",),)
pushfirst!(Base.DEPOT_PATH,joinpath(homedir(), ".julia",),)
unique!(Base.DEPOT_PATH)

try
    Pkg.Registry.add(
        Pkg.RegistrySpec(
            path = joinpath(splitpath(@__DIR__)...),
            )
        )
catch e
    @warn("ignoring exception: ", e,)
end
