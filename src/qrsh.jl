struct QRSH <: ClusterManager
    np::Integer
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
        qrsh_cmd = `qrsh -V -N $jobname -now n -wd $wd "$cmd"`

        stream_proc = [open(qrsh_cmd) for i in 1:np]

        for i in 1:np
            config = WorkerConfig()
            config.io = stream_proc[i]

            @show stream_proc[i]

            config.userdata = Dict{Symbol, Any}(:task => i)
            push!(launched, config)
            notify(c)
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
    close(get(config.io))

    kill(get(config.io),15)

end


qrsh(n::Int; kwargs...) = addprocs(QRSH(n); kwargs...)
