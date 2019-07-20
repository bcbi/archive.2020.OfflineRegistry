import Pkg;
import UUIDs;

offline_registry_name = Pkg.TOML.parsefile(
    joinpath(splitpath(@__DIR__)..., "Registry.toml")
    )["name"];
offline_registry_uuid_string = Pkg.TOML.parsefile(
    joinpath(splitpath(@__DIR__)..., "Registry.toml")
    )["uuid"];
offline_registry_uuid = UUIDs.UUID(offline_registry_uuid_string)
pushfirst!(Base.DEPOT_PATH,joinpath(splitpath(@__DIR__)..., "depot",),);
pushfirst!(
    Base.DEPOT_PATH,
    joinpath(
        homedir(),
        ".julia.isolated",
        offline_registry_name,
        offline_registry_uuid_string,
        ),
    );
filter!((x) -> !(Base.Filesystem.samefile(expanduser(x),expanduser("~/.julia")) || lowercase(strip(abspath(expanduser(x)))) == lowercase(strip(abspath(expanduser("~/.julia")))) || Base.Filesystem.samefile(x,"~/.julia") || lowercase(strip(abspath(x))) == lowercase(strip(abspath("~/.julia"))) || Base.Filesystem.samefile(expanduser(x),expanduser(joinpath(homedir(), ".julia"))) || lowercase(strip(abspath(expanduser(x)))) == lowercase(strip(abspath(expanduser(joinpath(homedir(), ".julia"))))) || Base.Filesystem.samefile(x,joinpath(homedir(), ".julia")) || lowercase(strip(abspath(x))) == lowercase(strip(abspath(joinpath(homedir(), ".julia"))))), Base.DEPOT_PATH);
unique!(Base.DEPOT_PATH);

try
    if !any(
            [
                (x.name == offline_registry_name &&
                    (x.uuid == offline_registry_uuid_string ||
                        x.uuid == offline_registry_uuid)) for
                            x in Pkg.Types.collect_registries()
                ]
            )
        Pkg.Registry.add(
            Pkg.RegistrySpec(path = joinpath(splitpath(@__DIR__)...),)
            );
    end
catch e
    @warn("ignoring exception: ", e,);
end
