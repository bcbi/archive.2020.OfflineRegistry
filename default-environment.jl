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
filter!((x) -> !(Base.Filesystem.samefile(expanduser(x),expanduser("~/.julia")) || lowercase(strip(abspath(expanduser(x)))) == lowercase(strip(abspath(expanduser("~/.julia")))) || Base.Filesystem.samefile(x,"~/.julia") || lowercase(strip(abspath(x))) == lowercase(strip(abspath("~/.julia"))) || Base.Filesystem.samefile(expanduser(x),expanduser(joinpath(homedir(), ".julia"))) || lowercase(strip(abspath(expanduser(x)))) == lowercase(strip(abspath(expanduser(joinpath(homedir(), ".julia"))))) || Base.Filesystem.samefile(x,joinpath(homedir(), ".julia")) || lowercase(strip(abspath(x))) == lowercase(strip(abspath(joinpath(homedir(), ".julia"))))), Base.DEPOT_PATH);
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
