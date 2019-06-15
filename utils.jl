import Pkg

function maketempdir()::String
    dir::String = mktempdir()
    atexit(() -> rm(dir; force = true, recursive = true,))
    return dir
end

mutable struct DummyOutputWrapperStruct{I, F, S, O}
    previous_time_seconds::I
    f::F
    interval_seconds::I
    dummy_output::S
    io::O
end

function DummyOutputWrapperStruct(
        ;
        interval_seconds::I = 60,
        initial_offset_seconds::I = interval_seconds,
        f::F,
        dummy_output::S = "This is a dummy line of output",
        io::O = Base.stdout,
        )::DummyOutputWrapperStruct{I, F, S, O} where
            I <: Integer where
            F <: Function where
            S <: AbstractString where
            O <: IO
    current_time_seconds::I = floor(I, time())
    initial_time_seconds::I = current_time_seconds + initial_offset_seconds
    wrapper_struct::DummyOutputWrapperStruct{I, F, S} =
        DummyOutputWrapperStruct(
            initial_time_seconds,
            f,
            interval_seconds,
            dummy_output,
            io,
            )
    return wrapper_struct
end

function (x::DummyOutputWrapperStruct{I, F, S, O})() where
        I <: Integer where
        F <: Function where
        S <: AbstractString where
        O <: IO
    current_time_seconds::I = floor(I, time())
    previous_time_seconds::I = x.previous_time_seconds
    f::F = x.f
    interval_seconds::I = x.interval_seconds
    dummy_output::S = x.dummy_output
    io::O = x.io
    elapsed_seconds::Int = current_time_seconds - previous_time_seconds
    print_dummy_output::Bool = elapsed_seconds > interval_seconds
    if print_dummy_output
        println(io, dummy_output)
        x.previous_time_seconds = current_time_seconds
    end
    f_result = f()
    return f_result
end

function _dummy_output_wrapper(
        ;
        f::F,
        interval_seconds::I = 60,
        initial_offset_seconds::I = interval_seconds,
        dummy_output::S = "This is a dummy line of output",
        io::O = Base.stdout,
        ) where
            I <: Integer where
            F <: Function where
            S <: AbstractString where
            O <: IO
    wrapper_struct::DummyOutputWrapperStruct{I, F, S, O} =
        DummyOutputWrapperStruct(
            ;
            f = f,
            interval_seconds = interval_seconds,
            initial_offset_seconds = initial_offset_seconds,
            dummy_output = dummy_output,
            )
    function my_wrapper_function()
        result = wrapper_struct()
        return result
    end
    return my_wrapper_function
end

function _command_ran_successfully(
        cmd::Base.AbstractCmd;
        max_attempts::Integer = 10,
        max_seconds_per_attempt::Real = 540,
        seconds_to_wait_between_attempts::Real = 30,
        error_on_failure::Bool = true,
        last_resort_run::Bool = true,
        before::Function = () -> (),
        )::Bool
    success_bool::Bool = false

    my_false = dummy_output_wrapper(
        ;
        f = () -> false,
        interval_seconds = 60,
        initial_offset_seconds = 60,
        dummy_output = "Still waiting between attempts...",
        io = Base.stdout,
        )

    for attempt = 1:max_attempts
        if success_bool
        else
            @debug(string("Attempt $(attempt)"))
            if attempt > 1
                timedwait(
                    () -> my_false(),
                    float(seconds_to_wait_between_attempts);
                    pollint = float(1.0),
                    )
            end
            before()
            p = run(cmd; wait = false,)
            my_process_exited = dummy_output_wrapper(
                ;
                f = () -> process_exited(p),
                interval_seconds = 60,
                initial_offset_seconds = 60,
                dummy_output = "The process is still running...",
                io = Base.stdout,
                )
            timedwait(
                () -> my_process_exited(),
                float(max_seconds_per_attempt),
                pollint = float(1.0),
                )
            if process_running(p)
                success_bool = false
                try
                    kill(p, Base.SIGTERM)
                catch exception
                    @warn("Ignoring exception: ", exception)
                end
                try
                    kill(p, Base.SIGKILL)
                catch exception
                    @warn("Ignoring exception: ", exception)
                end
            else
                success_bool = try
                    success(p)
                catch exception
                    @warn("Ignoring exception: ", exception)
                    false
                end
            end
        end
    end
    if !success_bool && last_resort_run
        @debug(string("Attempting the last resort run..."))
        run(cmd)
        success_bool = true
    end
    if success_bool
        @debug(string("Command ran successfully."),)
    else
        if error_on_failure
            error(string("Command did not run successfully."),)
        else
            @warn(string("Command did not run successfully."),)
        end
    end
    return success_bool
end

function _retry_function_until_success(
        f::Function;
        max_attempts::Integer = 10,
        seconds_to_wait_between_attempts::Real = 30,
        )
    success_bool::Bool = false
    f_result = nothing

    my_false = _dummy_output_wrapper(
        ;
        f = () -> false,
        interval_seconds = 60,
        initial_offset_seconds = 60,
        dummy_output = "Still waiting between attempts...",
        io = Base.stdout,
        )

    for attempt = 1:max_attempts
        if success_bool
        else
            @debug(string("Attempt $(attempt)"))
            if attempt > 1
                timedwait(
                    () -> my_false(),
                    float(seconds_to_wait_between_attempts);
                    pollint = float(1.0),
                    )
            end
            @debug(string("Running the provided function..."))
            success_bool = true
            f_result = try
                f()
            catch exception
                success_bool = false
                @warn("Ignoring exception: ", exception)
                nothing
            end
        end
    end

    if success_bool
        @debug(string("Function ran successfully."),)
        return f_result
    else
        error(string("Function did not run successfully."),)
    end
end


function _git_clone_registry(url::AbstractString)::String
    tmp = maketempdir()
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
    return tmp
end

function _git_clone_repo(url::AbstractString)::String
    tmp = maketempdir()
    Base.shred!(LibGit2.CachedCredentials()) do creds
        LibGit2.with(
            Pkg.GitTools.clone(
                url,
                tmp;
                header = "git-repo from $(repr(url))",
                credentials = creds,
                )
            ) do repo
        end
    end
    return tmp
end

function _Pkg_add_name_ignore_julia_version_error(
        name::AbstractString,
        )::Nothing
    try
        Pkg.add(name)
    catch e
        if occursin("Unsatisfiable requirements detected", repr(a)) &&
                occursin("restricted by julia compatibility", repr(a))
            @debug("ignoring error: ", e,)
        else
            @warn("rethrowing error: ", e,)
        end
    end
    return nothing
end
