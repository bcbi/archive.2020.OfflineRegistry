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

@info("removing build/")
rm(
    joinpath(project_root, "build",);
    force = true,
    recursive = true,
    )
@info("successfully removed build/")

cd(original_directory)
