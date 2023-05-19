export qrsh

struct QRSH <: ClusterManager
    np::Integer
    wd::String
    time::Int
    memory::Int
    mp::Int
end


function launch(manager::QRSH, params::Dict, launched::Array,
        c::Condition)

    try
        np = manager.np
        home = ENV["HOME"]
        exename = params[:exename]
        exeflags = params[:exeflags]
        dir = params[:dir]
        wd = manager.wd
        time = "h_rt=$(manager.time)"
        mem = "mem_free=$(manager.memory)G"
        mp = manager.mp

        jobname = `julia-$(getpid())`

        cmd = `cd $dir '&&' $exename $exeflags $(worker_arg())`

        function create_qrsh_cmd(n::Int, single)
            if single
                jn = jobname
            else
                jn = "$(jobname)_$(n)"
            end

            return `qrsh -V -N $jn -now n -wd $wd -pe mp $mp -l $time,$mem "$cmd"`
        end

        single = np == 1

        if single
            @info "Starting job using qrsh command"
        else
            @info "Starting $np jobs using qrsh command"
        end

        for i in 1:np
            config = WorkerConfig()
            stream = open(create_qrsh_cmd(i, single))
            config.io = stream.out

            config.userdata = Dict{Symbol, Any}(:task => i, :process => stream)
            push!(launched, config)
            notify(c)

            if i == np
                single ? (@info "One worker added") : (@info "$np workers added")
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

function qrsh(n::Int;
    wdir=pwd(), timelimit::Int=10000, ram::Int=4, mp=1, topology=:master_worker, kwargs...)

    addprocs(QRSH(n, wdir, timelimit, ram, mp); topology=topology, kwargs...)
end
