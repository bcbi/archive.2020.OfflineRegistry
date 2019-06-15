import Pkg;

offline_registry_name = Pkg.TOML.parsefile(
    joinpath(splitpath(@__DIR__)..., "Registry.toml")
    )["name"]
offline_registry_uuid = Pkg.TOML.parsefile(
    joinpath(splitpath(@__DIR__)..., "Registry.toml")
    )["uuid"]
pushfirst!(Base.DEPOT_PATH,joinpath(splitpath(@__DIR__)..., "depot",),);
pushfirst!(
    Base.DEPOT_PATH,
    joinpath(
        homedir(),
        ".julia.isolated",
        offline_registry_name,
        offline_registry_uuid,
        ),
    );
unique!(Base.DEPOT_PATH);

if !isfile(
        joinpath(
            homedir(),
            ".julia.isolated",
            offline_registry_name,
            offline_registry_uuid,
            "environments",
            string("v", VERSION.major, ".", VERSION.minor,),
            "Project.toml",
            )
        )
    mkpath(
        joinpath(
            homedir(),
            ".julia.isolated",
            offline_registry_name,
            offline_registry_uuid,
            "environments",
            string("v", VERSION.major, ".", VERSION.minor,),
            )
        );
    touch(
        joinpath(
            homedir(),
            ".julia.isolated",
            offline_registry_name,
            offline_registry_uuid,
            "environments",
            string("v", VERSION.major, ".", VERSION.minor,),
            "Project.toml",
            )
        );
end

Pkg.activate(
    joinpath(
        homedir(),
        ".julia.isolated",
        offline_registry_name,
        offline_registry_uuid,
        "environments",
        string("v", VERSION.major, ".", VERSION.minor,),
        )
    );
