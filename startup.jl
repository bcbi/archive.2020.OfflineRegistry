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
