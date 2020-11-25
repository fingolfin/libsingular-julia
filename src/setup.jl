module Setup

using Singular_jll
using lib4ti2_jll

# add shell scripts that startup another julia for some lib4ti2 programs
function regenerate_4ti2_wrapper(binpath, wrapperpath)
    mkpath("$wrapperpath")

    if Sys.iswindows()
        LIBPATH_env = "PATH"
    elseif Sys.isapple()
        LIBPATH_env = "DYLD_FALLBACK_LIBRARY_PATH"
    else
        LIBPATH_env = "LD_LIBRARY_PATH"
    end

    function force_symlink(p::AbstractString, np::AbstractString)
        rm(np; force = true)
        symlink(p, np)
    end

    for tool in ("4ti2gmp", "4ti2int32", "4ti2int64", "zsolve")
        force_symlink(joinpath(binpath, tool), joinpath(wrapperpath, tool))
    end

    for tool in ("graver", "hilbert", "markov")
        toolpath = joinpath(wrapperpath, tool)
        write(toolpath, """
        #!/bin/sh
        export $(LIBPATH_env)="$(lib4ti2_jll.LIBPATH[])"
        . $(binpath)/$(tool) "\$@"
        """)
        chmod(toolpath, 0o777)
    end
end

#
# put the wrapper inside this package, but use different wrappers for each
# minor Julia version as those may get different versions of the various JLLs
#
# TODO/FIXME: don't write into the package directory; instead use a scratch space
# obtained via <https://github.com/JuliaPackaging/Scratch.jl> -- however, that
# requires Julia >= 1.5; so we can't use it until we drop support for Julia 1.3 & 1.4.
#
const wrapperpath = abspath(joinpath(@__DIR__, "..", "bin", "v$(VERSION.major).$(VERSION.minor)"))
@info "Regenerating 4ti2 wrappers in $(wrapperpath)"
regenerate_4ti2_wrapper(joinpath(lib4ti2_jll.find_artifact_dir(), "bin"), wrapperpath)

# make sure Singular can find the wrappers
function __init__()
    ENV["PATH"] = wrapperpath * ":" * ENV["PATH"]
end


"""
    execute(cmd)

Run a command object. Returns a named tuple containing the stdout and stderr
as well as the exit code of the command.
"""
function execute(cmd::Base.Cmd)
    out = IOBuffer()
    err = IOBuffer()
    process = run(pipeline(ignorestatus(cmd), stdout=out, stderr=err))
    return (stdout = String(take!(out)),
            stderr = String(take!(err)),
            code = process.exitcode)
end

#
# regenerate src/libraryfuncdictionary.jl by parsing the list
# of library functions exported by Singular
#
function regenerate_libraryfuncdictionary(prefixpath)

    library_dir = get(ENV, "SINGULAR_LIBRARY_DIR", abspath(joinpath(prefixpath, "share", "singular", "LIB")))
    filenames = filter(x -> endswith(x, ".lib"), readdir(library_dir))
    output_filename = abspath(joinpath(@__DIR__, "libraryfuncdictionary.jl"))

    @info "Regenerating $(output_filename)"

    #=
      Loops over all libraries and executes libparse on it.
      The first three lines of the libparse output are general information
      about the library, so we ignore it. We are only interested in the
      first column (library name) and the third column (globally exposed or not).
      All other columns (containing info such as line numbers, library name, etc)
      are ignored.
    =#
    cd(abspath(joinpath(prefixpath, "bin"))) do
        open(output_filename, "w") do outputfile
            println(outputfile, "libraryfunctiondictionary = Dict(")
            for i in filenames
                full_path = joinpath(library_dir, i)
                libs = Singular_jll.libparse() do exe
                    execute(`$exe $full_path`)
                end
                if libs.stderr != ""
                    error("from libparse: $(libs.stderr)")
                end
                libs_splitted = split(libs.stdout,"\n")[4:end - 1]
                libs_splitted = [split(i, " ", keepempty = false) for i in libs_splitted]
                println(outputfile, ":$(i[1:end - 4]) => [")
                for j in libs_splitted
                    println(outputfile, """[ "$(j[1])", "$(j[3])" ],""")
                end
                println(outputfile, "],\n")
            end
            println(outputfile, ")\n")
        end
    end
end

regenerate_libraryfuncdictionary(Singular_jll.find_artifact_dir())

end # module
