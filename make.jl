import Dates
import LibGit2
import Pkg

original_directory = pwd()
project_root = joinpath(splitpath(@__DIR__)...)
cd(project_root)

rm(
    joinpath(project_root, "STARTED",);
    force = true,
    recursive = true,
    )
open(joinpath(project_root, "STARTED",), "w",) do f
    write(f, "$repr(Dates.now())\n",)
end

@info("parsing `offline.toml`...")
configuration = Pkg.TOML.parsefile("offline.toml")
@info("successfully parsed `offline.toml`...")

@info("downloading Project.toml and Manifest.toml files...")
projects_downloads = String[]
for url in configuration["toml"]["project"]["include"]
    @info("downloading $(repr(url))")
    push!(
        projects_downloads,
        Base.download(url),
        )
end
manifests_downloads = String[]
for url in configuration["toml"]["manifest"]["include"]
    @info("downloading $(repr(url))")
    push!(
        manifests_downloads,
        Base.download(url),
        )
end
@info("successfully downloaded all Project.toml and Manifest.toml files")

@info("cloning registries...")
registries_clones = String[]
for url in configuration["registry"]["include"]
    tmp = mktempdir()
    push!(registries_clones, tmp,)
    Base.shred!(LibGit2.CachedCredentials()) do creds
        LibGit2.with(
            Pkg.GitTools.clone(
                url,
                tmp;
                header = "registry from $(repr(url))",
                credentials = creds,
                )
            ) do repo
        end
    end
end
@info("successfully cloned all registries")

@info("processing the manifests of the given packages")
packages_to_manifest_process = String[]
append!(
    packages_to_manifest_process,
    strip.(configuration["package"]["build"]),
    )
append!(
    packages_to_manifest_process,
    strip.(configuration["package"]["warmup"]),
    )
append!(
    packages_to_manifest_process,
    strip.(collect(keys(configuration["build"]["branches"]))),
    )
append!(
    packages_to_manifest_process,
    strip.(collect(keys(configuration["build"]["versions"]))),
    )
for file in manifests_downloads
    append!(
        packages_to_manifest_process,
        sort(unique(strip.(collect(keys(Pkg.TOML.parsefile(file)))))),
        )
end
for file in projects_downloads
    append!(
        packages_to_manifest_process,
        sort(unique(strip.(collect(keys(Pkg.TOML.parsefile(file)["deps"]))))),
        )
end
unique!(packages_to_manifest_process)
sort!(packages_to_manifest_process)
original_depot_path = [x for x in Base.DEPOT_PATH]
my_depot = joinpath(project_root, "depot",)
my_environment = joinpath(project_root, "environments", "temporary",)
rm(my_depot; force = true, recursive = true,)
rm(my_environment;force = true,recursive = true,)
empty!(Base.DEPOT_PATH)
pushfirst!(Base.DEPOT_PATH, my_depot,)
Pkg.activate(my_environment)
results_of_manifest_processing = String[]
for url in configuration["registry"]["include"]
    Pkg.Registry.add(Pkg.RegistrySpec(url=url,))
end
Pkg.Registry.update()
for name in packages_to_manifest_process
    rm(
        joinpath(my_environment, "Project.toml",);
        force = true,
        recursive = true,
        )
    rm(
        joinpath(my_environment, "Manifest.toml",);
        force = true,
        recursive = true,
        )
    Pkg.add(name)
    environment_manifest_contents = Pkg.TOML.parsefile(
        joinpath(my_environment, "Manifest.toml",)
        )
    append!(
        results_of_manifest_processing,
        strip.(collect(keys(environment_manifest_contents))),
        )
end
rm(my_depot; force = true, recursive = true,)
rm(my_environment;force = true,recursive = true,)
unique!(results_of_manifest_processing)
sort!(results_of_manifest_processing)
@info("finished processing the manifests of the given packages")

@info("cloning package repositories...")
packages_to_clone = String[]
append!(
    packages_to_clone,
    strip.(packages_to_manifest_process),
    )
append!(
    packages_to_clone,
    strip.(results_of_manifest_processing),
    )
unique!(packages_to_clone)
sort!(packages_to_clone)
@debug("Packages to clone ($(length(packages_to_clone))): ")
for i = 1:length(packages_to_clone)
    @debug("$(i). $(packages_to_clone[i])")
end
rm(
    joinpath(project_root, "packages",);
    force = true,
    recursive = true,
    )
rm(
    joinpath(project_root, "repos",);
    force = true,
    recursive = true,
    )
registry_toml = Pkg.TOML.parsefile(joinpath(project_root, "Registry.toml.in"))
registry_toml["repo"] = project_root
packages_section = get(registry_toml,"packages",Dict{String,Any}(),)
exclude = configuration["package"]["exclude"]
branches_to_build = configuration["build"]["branches"]
branches_to_build_names = collect(keys(branches_to_build))
n = length(registries_clones)
for i = 1:n
    registry_root = registries_clones[i]
    registry_file = joinpath(registry_root, "Registry.toml",)
    registry_config = Pkg.TOML.parsefile(registry_file)
    registry_packages = registry_config["packages"]
    registry_packages_uuids = collect(keys(registry_packages))
    p = length(registry_packages_uuids)
    for j = 1:p
        uuid = registry_packages_uuids[j]
        name = registry_packages[uuid]["name"]
        if !(name in exclude)
            old_package_path = registry_packages[uuid]["path"]
            new_package_path = joinpath(
                "packages",
                name[1:1],
                name,
                )
            new_repo_path = joinpath(
                "repos",
                name[1:1],
                string(name, ".jl.git",),
                )
            package_source = joinpath(registry_root, old_package_path,)
            package_destination = joinpath(project_root, new_package_path,)
            repo_destination = joinpath(project_root, new_repo_path,)
            mkpath(package_destination)
            package_toml = Pkg.TOML.parsefile(
                joinpath(package_source,"Package.toml",)
                )
            original_url = package_toml["repo"]
            package_toml["repo"] = repo_destination
            rm(
                joinpath(package_destination, "Package.toml",);
                force = true,
                recursive = true,
                )
            open(joinpath(package_destination, "Package.toml",), "w") do f
                Pkg.TOML.print(f, package_toml,)
            end
            cp(
                joinpath(package_source, "Compat.toml",),
                joinpath(package_destination, "Compat.toml",);
                force = true,
                )
            cp(
                joinpath(package_source, "Versions.toml",),
                joinpath(package_destination, "Versions.toml",);
                force = true,
                )
            try
                cp(
                    joinpath(package_source, "Deps.toml",),
                    joinpath(package_destination, "Deps.toml",);
                    force = true,
                    )
            catch e
                @debug(
                    "ignoring exception: ",
                    e,
                    joinpath(package_source, "Deps.toml",),
                    )
            end
            if name in packages_to_clone
                @debug("Cloning package $(j) of $(p)")
                mkpath(repo_destination)
                tmp = mktempdir()
                Base.shred!(LibGit2.CachedCredentials()) do creds
                    LibGit2.with(
                        Pkg.GitTools.clone(
                            original_url,
                            tmp;
                            header = "git-repo from $(repr(original_url))",
                            credentials = creds,
                            )
                        ) do repo
                    end
                end
                cp(
                    tmp,
                    repo_destination;
                    force = true,
                    )
                @debug("name: ", name,)
                @debug("branches_to_build_names: ", branches_to_build_names,)
                if name in branches_to_build_names
                    branches = branches_to_build[name]
                    repo = LibGit2.GitRepo(repo_destination)
                    try
                        all_remotes = LibGit2.remotes(repo)
                        if "origin" in all_remotes
                            remote_name = "origin"
                        else
                            remote_name = first(all_remotes)
                        end
                        remote = LibGit2.get(
                            LibGit2.GitRemote,
                            repo,
                            remote_name,
                            )
                        for branch in branches
                            branch_already_exists = isa(
                                LibGit2.lookup_branch(repo, branch),
                                LibGit2.GitReference,
                                )
                            if branch_already_exists
                                @debug(
                                    string(
                                        "Branch $(branch) already exists in ",
                                        "package $(name)",
                                        )
                                    )
                            else
                                @debug(
                                    string(
                                        "Checking out branch $(branch) for ",
                                        "package $(name)",
                                        )
                                    )
                                remote_tip = LibGit2.GitCommit(
                                    repo,
                                    "refs/remotes/$(remote_name)/$(branch)",
                                    )
                                LibGit2.branch!(
                                    repo,
                                    branch,
                                    string(LibGit2.GitHash(remote_tip));
                                    track = branch,
                                    )
                            end
                        end
                    catch e1
                        @warn("ignoring exception: ", e1,)
                    finally
                        try
                            close(remote)
                        catch e2
                            @warn("ignoring exception: ", e2,)
                        end
                    end
                end
            end
            packages_section[uuid] = Dict(
                "name" => name,
                "path" => new_package_path,
                )
        end
    end
end
@info("successfully cloned all package repositories")

@info("generating Registry.toml file...")
registry_toml["packages"] = packages_section
registry_toml_path = joinpath(project_root, "Registry.toml",)
open(registry_toml_path, "w") do f
    Pkg.TOML.print(f, registry_toml,)
end
@info("successfully wrote Registry.toml file to $(repr(registry_toml_path))")

@info("tracking files and staging changes...")
project_repo = LibGit2.GitRepo(project_root)
LibGit2.add!(project_repo, "Registry.toml",)
LibGit2.add!(project_repo, "packages",)
@info("successfully tracked all files and staged all changes")

@info("committing changes...")
commit_msg = "Automated commit made by make.jl on $(repr(Dates.now()))"
sig = LibGit2.Signature(
    configuration["git"]["config"]["user"]["name"],
    configuration["git"]["config"]["user"]["email"],
    )
LibGit2.commit(project_repo,commit_msg;author = sig,committer = sig,)
all_project_remotes = LibGit2.remotes(project_repo)
for project_remote in all_project_remotes
    LibGit2.remote_delete(project_repo, project_remote,)
end
@info("successfully committed all changes")

@info("adding packages to depot and building packages...")
rm(my_depot; force = true, recursive = true,)
rm(my_environment;force = true,recursive = true,)
empty!(Base.DEPOT_PATH)
pushfirst!(Base.DEPOT_PATH, my_depot,)
Pkg.activate(my_environment)
Pkg.Registry.add(Pkg.RegistrySpec(path=project_root,))
packages_to_warmup = sort(
    unique(
        strip.(configuration["package"]["warmup"])
        )
    )
n = length(packages_to_clone)
for i = 1:n
    @debug("Building package $(i) of $(n)")
    name = packages_to_clone[i]
    rm(
        joinpath(my_environment, "Project.toml",);
        force = true,
        recursive = true,
        )
    rm(
        joinpath(my_environment, "Manifest.toml",);
        force = true,
        recursive = true,
        )
    Pkg.add(name)
    try
        Pkg.build(name; verbose = true,)
    catch e1
        @warn("ignoring exception: ", e1,)
    end
    for package_to_warmup in intersect(
            packages_to_warmup,
            keys(
                Pkg.TOML.parsefile(
                    joinpath(my_environment, "Manifest.toml",)
                    )
                ),
            )
        Pkg.add(package_to_warmup)
        try
            Pkg.build(package_to_warmup; verbose = true,)
        catch e2
            @warn("ignoring exception: ", e2,)
        end
        Base.eval(
            Main,
            Base.Meta.parse("import $(package_to_warmup)"),
            )
    end
end
versions_to_build = configuration["build"]["versions"]
versions_to_build_names = collect(keys(versions_to_build))
n = length(versions_to_build_names)
for i = 1:n
    name = versions_to_build_names[i]
    versions = versions_to_build[name]
    p = length(versions)
    for j = 1:p
        @debug("[package $(i) of $(n)] Building version $(j) of $(p)")
        version = versions[j]
        rm(
            joinpath(my_environment, "Project.toml",);
            force = true,
            recursive = true,
            )
        rm(
            joinpath(my_environment, "Manifest.toml",);
            force = true,
            recursive = true,
            )
        Pkg.add(Pkg.PackageSpec(name=name, version=version,))
        try
            Pkg.build(name; verbose = true,)
        catch e1
            @warn("ignoring exception: ", e1,)
        end
        for package_to_warmup in intersect(
                packages_to_warmup,
                keys(
                    Pkg.TOML.parsefile(
                        joinpath(my_environment, "Manifest.toml",)
                        )
                    ),
                )
            Pkg.add(package_to_warmup)
            try
                Pkg.build(package_to_warmup; verbose = true,)
            catch e2
                @warn("ignoring exception: ", e2,)
            end
            Base.eval(
                Main,
                Base.Meta.parse("import $(package_to_warmup)"),
                )
        end
    end
end
n = length(branches_to_build_names)
for i = 1:n
    name = branches_to_build_names[i]
    branches = branches_to_build[name]
    p = length(branches)
    for j = 1:p
        @debug("[package $(i) of $(n)] Building branch $(j) of $(p)")
        branch = branches[j]
        rm(
            joinpath(my_environment, "Project.toml",);
            force = true,
            recursive = true,
            )
        rm(
            joinpath(my_environment, "Manifest.toml",);
            force = true,
            recursive = true,
            )
        Pkg.add(Pkg.PackageSpec(name=name, rev=branch,))
        try
            Pkg.build(name; verbose = true,)
        catch e1
            @warn("ignoring exception: ", e1,)
        end
        for package_to_warmup in intersect(
                packages_to_warmup,
                keys(
                    Pkg.TOML.parsefile(
                        joinpath(my_environment, "Manifest.toml",)
                        )
                    ),
                )
            Pkg.add(package_to_warmup)
            try
                Pkg.build(package_to_warmup; verbose = true,)
            catch e2
                @warn("ignoring exception: ", e2,)
            end
            Base.eval(
                Main,
                Base.Meta.parse("import $(package_to_warmup)"),
                )
        end
    end
end
rm(my_environment;force = true,recursive = true,)

rm(joinpath(my_depot, "compiled",);force = true,recursive = true,)

empty!(Base.DEPOT_PATH)
for x in original_depot_path
    push!(Base.DEPOT_PATH, x,)
end
unique!(Base.DEPOT_PATH)

@info("successfully added packages to depot and built packages")

rm(
    joinpath(project_root, "FINISHED",);
    force = true,
    recursive = true,
    )
open(joinpath(project_root, "FINISHED",), "w",) do f
    write(f, "$repr(Dates.now())\n",)
end

cd(original_directory)
