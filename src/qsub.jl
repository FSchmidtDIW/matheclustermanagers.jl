export qsub

struct QSUB <: ClusterManager
    np::Integer
    wd::String
    time::Int
    memory::Int
end


function launch(manager::QSUB, params::Dict, launched::Array,
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

        jobname = `julia-$(getpid())`
        outfile = `$dir/$jobname.out`
        cmd = `cd $dir '&&' $exename $exeflags $(worker_arg())` |>
            Base.shell_escape
        qsub1 = `echo $(cmd)`
        qsub2 = `qsub -N $jobname -terse -j y -R y -wd $wd -l $time,$mem -t 1-$np -V -o $outfile`
        qsub_cmd = pipeline(qsub1, qsub2)

        out = open(qsub_cmd)
        if !success(out)
            throw(error())
        end

        id = chomp(split(readline(out),'.')[1])
        if endswith(id, "[]")
            id = id[1:end-2]
        end

        @info "Job $id is in queue"

        prog = ProgressUnknown(
            "Job id is $id, waiting for job to start",
            spinner=true
        )
        outfile = outfile |> Base.shell_escape
        while isfile(outfile) == false
            ProgressMeter.update!(prog, spinner=raw"|/-\-")
            sleep(1)
        end
        ProgressMeter.finish!(prog, spinner="*")

        println("Found job file: $outfile")

        cmd_config = `tail -f $outfile`

        config = WorkerConfig()
        stream = open(detach(cmd_config))
        @show stream
        config.io = stream.out
        config.userdata = Dict{Symbol, Any}(
            :job=>id,
            :task=>1,
            :iofile=>outfile
        )
        push!(launched, config)
        @show config
        println("pushed config")
        notify(c)
        println("notifying")

    catch e
        println("Error launching workers")
        throw(e)
    end

end


function manage(manager::QSUB, id::Integer, config::WorkerConfig,
    op::Symbol)
end


function kill(manager::QSUB, id::Int64, config::WorkerConfig)
    remotecall(exit, id)
    close(get(config.io))

    if isfile(config.userdata[:iofile])
        rm(config.userdata[:iofile])
    end
end

function qsub(n::Int; wdir=pwd(), timelimit::Int=10000, ram::Int=4,  kwargs...)
    addprocs(QSUB(n, wdir, timelimit, ram); kwargs...)
end