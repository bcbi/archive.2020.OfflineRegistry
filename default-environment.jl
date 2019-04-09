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
end

Pkg.activate(
    joinpath(
        homedir(),
        ".julia",
        "environments",
        string("v", VERSION.major, ".", VERSION.minor,),
        )
    );
