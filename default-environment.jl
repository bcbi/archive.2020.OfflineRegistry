import Pkg;

if !isdir(
        joinpath(
            homedir(),
            ".julia",
            "environments",
            string("v", VERSION.major, ".", VERSION.minor,),
            )
        )
    mkpath(
        joinpath(
            homedir(),
            ".julia",
            "environments",
            string("v", VERSION.major, ".", VERSION.minor,),
            )
        );
    touch(
        joinpath(
            homedir(),
            ".julia",
            "environments",
            string("v", VERSION.major, ".", VERSION.minor,),
            "Project.toml",
            )
        );
end

Pkg.activate(
    joinpath(
        homedir(),
        ".julia",
        "environments",
        string("v", VERSION.major, ".", VERSION.minor,),
        )
    );
