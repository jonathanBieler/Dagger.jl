module Dagger

import Serialization
import Serialization: AbstractSerializer, serialize, deserialize
import SparseArrays: sprand, SparseMatrixCSC

import MemPool
import MemPool: DRef, FileRef, poolget, poolset

import Base: collect, reduce

import LinearAlgebra
import LinearAlgebra: Adjoint, BLAS, Diagonal, Bidiagonal, Tridiagonal, LAPACK, LowerTriangular, PosDefException, Transpose, UpperTriangular, UnitLowerTriangular, UnitUpperTriangular, diagind, ishermitian, issymmetric
import Random
import Random: AbstractRNG

import UUIDs: UUID, uuid4

if !isdefined(Base, :ScopedValues)
    import ScopedValues: ScopedValue, with
else
    import Base.ScopedValues: ScopedValue, with
end
import TaskLocalValues: TaskLocalValue

if !isdefined(Base, :get_extension)
    import Requires: @require
end

import TimespanLogging
import TimespanLogging: timespan_start, timespan_finish

import Adapt

# Preferences
import Preferences: @load_preference, @set_preferences!

if @load_preference("distributed-package") == "DistributedNext"
    import DistributedNext
    import DistributedNext: Future, RemoteChannel, myid, workers, nworkers, procs, remotecall, remotecall_wait, remotecall_fetch, check_same_host
else
    import Distributed
    import Distributed: Future, RemoteChannel, myid, workers, nworkers, procs, remotecall, remotecall_wait, remotecall_fetch, check_same_host
end

include("lib/util.jl")
include("utils/dagdebug.jl")

# Distributed data
include("utils/locked-object.jl")
include("utils/tasks.jl")

import MacroTools: @capture, prewalk

include("options.jl")
include("processor.jl")
include("threadproc.jl")
include("context.jl")
include("utils/processors.jl")
include("dtask.jl")
include("cancellation.jl")
include("task-tls.jl")
include("scopes.jl")
include("utils/scopes.jl")
include("queue.jl")
include("thunk.jl")
include("submission.jl")
include("chunks.jl")
include("memory-spaces.jl")
include("rules.jl")

# Task scheduling
include("compute.jl")
include("utils/clock.jl")
include("utils/system_uuid.jl")
include("utils/caching.jl")
include("sch/Sch.jl"); using .Sch

# Data dependency task queue
include("datadeps.jl")
include("utils/haloarray.jl")
include("stencil.jl")

# Streaming
include("stream.jl")
include("stream-buffers.jl")
include("stream-transfer.jl")

# Array computations
include("array/darray.jl")
include("array/alloc.jl")
include("array/map-reduce.jl")
include("array/copy.jl")

# File IO
include("file-io.jl")

include("array/operators.jl")
include("array/indexing.jl")
include("array/setindex.jl")
include("array/matrix.jl")
include("array/sparse_partition.jl")
include("array/sort.jl")
include("array/linalg.jl")
include("array/mul.jl")
include("array/cholesky.jl")
include("array/lu.jl")
include("array/random.jl")

import KernelAbstractions, Adapt

# GPU
include("gpu.jl")

# Logging and Visualization
include("visualization.jl")
include("ui/gantt-common.jl")
include("ui/gantt-text.jl")
include("utils/logging-events.jl")
include("utils/logging.jl")
include("utils/viz.jl")

"""
    set_distributed_package!(value[="Distributed|DistributedNext"])

Set a [preference](https://github.com/JuliaPackaging/Preferences.jl) for using
either the Distributed.jl stdlib or DistributedNext.jl. You will need to restart
Julia after setting a new preference.
"""
function set_distributed_package!(value)
    MemPool.set_distributed_package!(value)
    TimespanLogging.set_distributed_package!(value)

    @set_preferences!("distributed-package" => value)
    @info "Dagger.jl preference has been set, restart your Julia session for this change to take effect!"
end

# Precompilation
import PrecompileTools: @compile_workload
include("precompile.jl")

function __init__()
    # Initialize system UUID
    system_uuid()

    @static if !isdefined(Base, :get_extension)
        @require Distributions="31c24e10-a181-5473-b8eb-7969acd0382f" begin
            include(joinpath(dirname(@__DIR__), "ext", "DistributionsExt.jl"))
        end
        @require Graphs="86223c79-3864-5bf0-83f7-82e725a168b6" begin
            @require GraphViz="f526b714-d49f-11e8-06ff-31ed36ee7ee0" begin
                include(joinpath(dirname(@__DIR__), "ext", "GraphVizExt.jl"))
            end
        end
        @require Colors="5ae59095-9a9b-59fe-a467-6f913c188581" begin
            include(joinpath(dirname(@__DIR__), "ext", "GraphVizSimpleExt.jl"))
            # TODO: Move to Pkg extensions
            @require Luxor="ae8d54c2-7ccd-5906-9d76-62fc9837b5bc" begin
                # Gantt chart renderer
                include("ui/gantt-luxor.jl")
            end
            @require Mux="a975b10e-0019-58db-a62f-e48ff68538c9" begin
                # Gantt chart HTTP server
                include("ui/gantt-mux.jl")
            end
            @require JSON3 = "0f8b85d8-7281-11e9-16c2-39a750bddbf1" begin
                include(joinpath(dirname(@__DIR__), "ext", "JSON3Ext.jl"))
            end
        end
        # TODO: Move to Pkg extensions
        @require ProfileSVG="132c30aa-f267-4189-9183-c8a63c7e05e6" begin
            # Profile renderer
            include("ui/profile-profilesvg.jl")
        end
        @require FFMPEG="c87230d0-a227-11e9-1b43-d7ebe4e7570a" begin
            @require FileIO="5789e2e9-d7fb-5bc7-8068-2c6fae9b9549" begin
                # Video generator
                include("ui/video.jl")
            end
        end
    end
    for tid in 1:Threads.nthreads()
        add_processor_callback!("__cpu_thread_$(tid)__") do
            ThreadProc(myid(), tid)
        end
    end

    # Set up @dagdebug categories, if specified
    try
        if haskey(ENV, "JULIA_DAGGER_DEBUG")
            empty!(DAGDEBUG_CATEGORIES)
            for category in split(ENV["JULIA_DAGGER_DEBUG"], ",")
                if category != ""
                    push!(DAGDEBUG_CATEGORIES, Symbol(category))
                end
            end
        end
    catch err
        @warn "Error parsing JULIA_DAGGER_DEBUG" exception=err
    end
end

end # module
