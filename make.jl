import Dates
import LibGit2
import Pkg
import UUIDs

if length(ARGS) != 4
    throw(
        ArgumentError(
            string(
                "Syntax: julia make.jl ",
                "\"REGISTRY_NAME\" \"REGISTRY_UUID\" ",
                "\"GIT_USER_NAME\" \"GIT_USER_EMAIL\"",
                )
            )
        )
end

const MY_REGISTRY_NAME = convert(String, strip(ARGS[1]))
const MY_REGISTRY_UUID = convert(String, strip(ARGS[2]))
const MY_REGISTRY_UUID_OBJECT = UUIDs.UUID(MY_REGISTRY_UUID)
const MY_GIT_USER_NAME = convert(String, strip(ARGS[3]))
const MY_GIT_USER_EMAIL = convert(String, strip(ARGS[4]))

original_directory = pwd()
project_root = joinpath(splitpath(@__DIR__)...)
cd(project_root)

function simple_retry_string(f::Function)::String
    need_to_continue::Bool = true
    f_result::String = ""
    while need_to_continue
        try
            f_result = f()
            need_to_continue = false
        catch exception
            need_to_continue = true
            @error("$(exception)", exception=exception,)
        end
    end
    return f_result
end

rm(
    joinpath(project_root, "build", "STARTED",);
    force = true,
    recursive = true,
    )
mkpath(joinpath(project_root, "build",))
open(joinpath(project_root, "build", "STARTED",), "w",) do f
    write(f, "$(repr(Dates.now()))\n",)
end

@info("loading utils.jl...")
include(joinpath(project_root,"utils.jl",))
@info("successfully loaded utils.jl")

@info("parsing `offline.toml`...")
configuration = Pkg.TOML.parsefile("offline.toml")
@info("successfully parsed `offline.toml`...")

@info("parsing `broken.packages.toml`...")
broken_packages = Pkg.TOML.parsefile("broken.packages.toml")
broken_packages_name = broken_packages["broken"]["packages"]["name"]
@info("successfully parsed `broken.packages.toml`...")

@info("downloading Project.toml and Manifest.toml files...")
projects_downloads = String[]
if haskey(configuration["include"], "projects")
    for project_toml_table in configuration["include"]["projects"]
        url = project_toml_table["url"]
        @info("downloading $(repr(url))")
        push!(
            projects_downloads,
            simple_retry_string(() -> Base.download(url)),
            )
    end
end
manifests_downloads = String[]
if haskey(configuration["include"], "manifests")
    for project_toml_table in configuration["include"]["manifests"]
        url = project_toml_table["url"]
        @info("downloading $(repr(url))")
        push!(
            manifests_downloads,
            simple_retry_string(() -> Base.download(url)),
            )
    end
end
@info("successfully downloaded all Project.toml and Manifest.toml files")

@info("cloning registries...")
registries_clones = String[]
packages_from_registries_to_download_all_packages = String[]
for registry_toml_table in configuration["include"]["registries"]
    url = registry_toml_table["url"]
    download_all_packages = get(
        registry_toml_table,
        "download_all_packages",
        false,
        )
    tmp = retry_function_until_success(
        () -> git_clone_registry(url);
        )
    push!(registries_clones, tmp,)
    registry_toml_file_path = joinpath(
        tmp,
        "Registry.toml",
        )
    registry_toml_file_parsed = Pkg.TOML.parsefile(
        registry_toml_file_path
        )
    registry_name = registry_toml_file_parsed["name"]
    registry_uuid = registry_toml_file_parsed["uuid"]
    if download_all_packages
        append!(
            packages_from_registries_to_download_all_packages,
            [x["name"] for x in
                collect(values(registry_toml_file_parsed["packages"]))],
            )
    end
    unique!(packages_from_registries_to_download_all_packages)
end
unique!(packages_from_registries_to_download_all_packages)
sort!(packages_from_registries_to_download_all_packages)
@info("successfully cloned all registries")

@info("processing the manifests of the given packages")
packages_to_manifest_process = String[]
names_from_combinations_to_build = String[]
pkgname_to_branchestobuild = Dict{String, Vector{String}}()
combinations_to_build = configuration["build"]["packages"]
for combination in combinations_to_build
    for package in combination
        if "name" in keys(package.values)
            name = convert(String, strip(package["name"]))
            push!(names_from_combinations_to_build, name)
            if "branch" in keys(package.values)
                branch = convert(String, strip(package["branch"]))
                if !haskey(pkgname_to_branchestobuild, name)
                    pkgname_to_branchestobuild[name] = String[]
                end
                push!(pkgname_to_branchestobuild[name], branch)
                unique!(pkgname_to_branchestobuild[name])
            end
        end
    end
end
unique!(names_from_combinations_to_build)
append!(
    packages_to_manifest_process,
    names_from_combinations_to_build,
    )
append!(
    packages_to_manifest_process,
    strip.(configuration["warmup"]["packages"]),
    )
for file in manifests_downloads
    append!(
        packages_to_manifest_process,
        sort(
            unique(strip.(collect(keys(Pkg.TOML.parsefile(file)))))
            ),
        )
end
for file in projects_downloads
    append!(
        packages_to_manifest_process,
        sort(
            unique(strip.(collect(keys(Pkg.TOML.parsefile(file)["deps"]))))
            ),
        )
end
my_own_project_toml_file = joinpath(
    project_root,
    "Project.toml",
    )
append!(
    packages_to_manifest_process,
    sort(
        unique(
            strip.(
                collect(
                    keys(
                        Pkg.TOML.parsefile(my_own_project_toml_file)["deps"]
                        )
                    )
                )
            )
        ),
    )
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
for registry_toml_table in configuration["include"]["registries"]
    url = registry_toml_table["url"]
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
    retry_function_until_success(
        () -> Pkg_add_name_ignore_julia_version_error(name);
        )
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
    strip.(packages_from_registries_to_download_all_packages),
    )
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
@debug(
    "Packages to clone: ",
    length(packages_to_clone),
    packages_to_clone,
    repr(packages_to_clone),
    )
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
registry_toml = Dict{String, Any}()
registry_toml["name"] = MY_REGISTRY_NAME
registry_toml["uuid"] = MY_REGISTRY_UUID
registry_toml["repo"] = project_root
registry_toml["description"] = """
This registry allows you to use Julia packages
 behind a firewall. For help, visit
 https://github.com/DilumAluthge/OfflineRegistry
"""
packages_section = get(registry_toml,"packages",Dict{String,Any}(),)
exclude = configuration["exclude"]["packages"]
append!(
    exclude,
    broken_packages["broken"]["packages"]["name"],
    )
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
                tmp = retry_function_until_success(
                    () -> git_clone_repo(original_url);
                    )
                cp(
                    tmp,
                    repo_destination;
                    force = true,
                    )
                if haskey(pkgname_to_branchestobuild, name)
                    branches = pkgname_to_branchestobuild[name]
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
commit_msg = "Automated commit made by https://github.com/DilumAluthge/OfflineRegistry on $(repr(Dates.now()))"
sig = LibGit2.Signature(
    MY_GIT_USER_NAME,
    MY_GIT_USER_EMAIL,
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
        strip.(configuration["warmup"]["packages"])
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
    retry_function_until_success(
        () -> Pkg_add_name_ignore_julia_version_error(name);
        )
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

combinations_to_build = configuration["build"]["packages"]
n = length(combinations_to_build)
for i = 1:n
    combination_i = combinations_to_build[i]
    num_packages_in_combination_i = length(combination_i)
    list_of_packagespecs = Vector{Pkg.Types.PackageSpec}(
        undef,
        num_packages_in_combination_i,
        )
    for j = 1:num_packages_in_combination_i
        combination_i_package_j = combination_i[j]
        my_kwargs_dict = Dict{Symbol, String}()
        if "name" in keys(combination_i_package_j.values)
            my_kwargs_dict[:name] = strip(
                combination_i_package_j["name"]
                )
        end
        if "branch" in keys(combination_i_package_j.values)
            my_kwargs_dict[:rev] = strip(
                combination_i_package_j["branch"]
                )
        end
        if "version" in keys(combination_i_package_j.values)
            my_kwargs_dict[:version] = strip(
                combination_i_package_j["version"]
                )
        end
        if length(my_kwargs_dict) > 0
            packagespec = Pkg.PackageSpec(; my_kwargs_dict...)
        end
        list_of_packagespecs[j] = packagespec
    end
    @debug(
        "Building combination $(i) of $(n)",
        combination,
        list_of_packagespecs,
        repr(combination),
        repr(list_of_packagespecs),
        )
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
    retry_function_until_success(
        () -> Pkg.add(list_of_packagespecs);
        )
    for ps in list_of_packagespecs
        try
            Pkg.build(ps; verbose = true,)
        catch e1
            @warn("ignoring exception: ", e1,)
        end
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
rm(my_environment;force = true,recursive = true,)

moved_out_of_depot_dir = joinpath(
    project_root,
    "movedoutofdepot",
    )
moved_out_of_depot_packages_dir = joinpath(
    moved_out_of_depot_dir,
    "packages",
    )
move_out_of_depot_list = configuration["move_out_of_depot"]["packages"]
unique!(move_out_of_depot_list)
sort!(move_out_of_depot_list)
n = length(move_out_of_depot_list)
for i = 1:n
    name = move_out_of_depot_list[i]
    @debug("Moving \"$(name)\" ($(i) of $(n)) out of depot")
    old_package_path = joinpath(
        my_depot,
        "packages",
        name,
        )
    new_package_path = joinpath(
        moved_out_of_depot_packages_dir,
        name,
        )
    rm(
        new_package_path;
        force = true,
        recursive = true,
        )
    mkpath(moved_out_of_depot_packages_dir)
    mv(
        old_package_path,
        new_package_path;
        force = true,
        )
end

rm(joinpath(my_depot, "compiled",);force = true,recursive = true,)
rm(my_environment;force = true,recursive = true,)

empty!(Base.DEPOT_PATH)
for x in original_depot_path
    push!(Base.DEPOT_PATH, x,)
end
unique!(Base.DEPOT_PATH)

@info("successfully added packages to depot and built packages")

rm(
    joinpath(project_root, "build", "FINISHED",);
    force = true,
    recursive = true,
    )
mkpath(joinpath(project_root, "build",))
open(joinpath(project_root, "build", "FINISHED",), "w",) do f
    write(f, "$(repr(Dates.now()))\n",)
end

cd(original_directory)
