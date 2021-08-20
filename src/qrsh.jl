export qrsh

struct QRSH <: ClusterManager
    np::Integer
    wd::String
    time::Int
    memory::Int
end


function launch(manager::QRSH, params::Dict, launched::Array,
        c::Condition)

    try
        np = manager.np
        home = ENV["HOME"]
        exename = params[:exename]
        exeflags = params[:exeflags]
        dir = params[:dir]

        jobname = `julia-$(getpid())`

        cmd = `cd $dir '&&' $exename $exeflags $(worker_arg())`
        qrsh_cmd = `qrsh -V -N $jobname -now n -wd $wd -l $time,$mem "$cmd"`

        if np == 1
            @info "Starting job using qrsh command"
        else
            @info "Starting $np jobs qrsh command"
        end

        stream_proc = [open(qrsh_cmd) for i in 1:np]

        for i in 1:np
            config = WorkerConfig()
            config.io = stream_proc[i]

            @show stream_proc[i]

            config.userdata = Dict{Symbol, Any}(:task => i, :process => io_proc)
            push!(launched, config)
            notify(c)

            @info "Added worker $i"

            if i == np
                @info "All workers added"
            end
        end

    catch e
        println("Error launching workers")
        throw(e)
    end

end


function manage(manager::QRSH, id::Int64, config::WorkerConfig,
    op::Symbol)
end


function kill(manager::QRSH, id::Int64, config::WorkerConfig)

    remotecall(exit,id)
    close(config.io)

    kill(config.userdata[:process], 15)
end

function qrsh(n::Int; wdir=pwd(), timelimit::Int=10000, ram::Int=4,  kwargs...)
    addprocs(QRSH(n, wdir, timelimit, ram); kwargs...)
end
