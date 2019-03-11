import Pkg

mkpath(
    joinpath(
        homedir(),
        ".julia",
        "environments",
        string("v", VERSION.major, ".", VERSION.minor,),
        )
    )

Pkg.activate(
    joinpath(
        homedir(),
        ".julia",
        "environments",
        string("v", VERSION.major, ".", VERSION.minor,),
        )
    )
