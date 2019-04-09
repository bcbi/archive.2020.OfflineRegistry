import Pkg;

pushfirst!(Base.DEPOT_PATH,joinpath(splitpath(@__DIR__)..., "depot",),); 
pushfirst!(Base.DEPOT_PATH,joinpath(homedir(), ".julia",),); 
unique!(Base.DEPOT_PATH); 

try
    if !any(
            [x.name ==
                Pkg.TOML.parsefile(joinpath(splitpath(@__DIR__)...,
                    "Registry.toml"))["name"] for x in
                        Pkg.Types.collect_registries()]
            )
        Pkg.Registry.add(
            Pkg.RegistrySpec(path = joinpath(splitpath(@__DIR__)...),)
            );
    end
catch e
    @warn("ignoring exception: ", e,);
end
