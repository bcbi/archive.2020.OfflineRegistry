original_directory = pwd()
project_root = joinpath(splitpath(@__DIR__)...)
cd(project_root)

@info("removing depot directory...")
rm(
    joinpath(project_root, "depot");
    force = true,
    recursive = true,
    )
@info("successfully removed depot directory")

@info("removing environments directory...")
rm(
    joinpath(project_root, "environments");
    force = true,
    recursive = true,
    )
@info("successfully removed environments directory")

@info("removing repos directory...")
rm(
    joinpath(project_root, "repos");
    force = true,
    recursive = true,
    )
@info("successfully removed repos directory")

@info("removing packages directory...")
rm(
    joinpath(project_root, "packages");
    force = true,
    recursive = true,
    )
@info("successfully removed packages directory")

@info("removing Registry.toml...")
rm(
    joinpath(project_root, "Registry.toml",);
    force = true,
    recursive = true,
    )
@info("successfully removed Registry.toml")

@info("removing STARTED and FINISHED")
rm(
    joinpath(project_root, "STARTED",);
    force = true,
    recursive = true,
    )
rm(
    joinpath(project_root, "FINISHED",);
    force = true,
    recursive = true,
    )
@info("successfully removed STARTED and FINISHED")

cd(original_directory)
