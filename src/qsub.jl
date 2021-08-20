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

        jobname = "julia-$(getpid())"
       
        cmd = `cd $dir '&&' $exename $exeflags $(worker_arg())` |>
            Base.shell_escape
        qsub1 = `echo $(cmd)`
        qsub2 = `qsub -N $jobname -terse -j y -R y -wd $wd -l $time,$mem -t 1-$np -V`
        qsub_cmd = pipeline(qsub1, qsub2)

        if np == 1
            @info "Starting job using qsub command"
        else
            @info "Starting $np jobs qsub command"
        end

        out = open(qsub_cmd)
        if !success(out)
            throw(error())
        end

        id = chomp(split(readline(out),'.')[1])
        if endswith(id, "[]")
            id = id[1:end-2]
        end

        @info "Job $id is in queue"

        filenames(i) = [
            "$wd/julia-$(getpid()).o$id-$i",
            "$wd/julia-$(getpid())-$i.o$id",
            "$wd/julia-$(getpid()).o$id.$i"
        ]

        for i in 1:np

            fnames = filenames(i)

            prog = ProgressUnknown(
                "Looking for output files",
                spinner=true
            )

            j = 0
            while (j=findfirst(x->isfile(x),fnames))==nothing
                ProgressMeter.update!(prog, spinner=raw"|/-\-")
                sleep(1)
            end
            fname = fnames[j]
            ProgressMeter.finish!(prog)

            @info "Found job file: $fname"

            cmd_config = `tail -f $fname`
            config = WorkerConfig()
            stream = open(detach(cmd_config))
            config.io = stream.out
            config.userdata = Dict{Symbol, Any}(
                :job=>id,
                :task=>i,
                :iofile=>fname
            )
            push!(launched, config)
            notify(c)
            @info "Added worker $i from job $id"

            if i == np
                @info "All workers from job $id added"
            end
        end
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
    close(config.io)

    if isfile(config.userdata[:iofile])
        rm(config.userdata[:iofile])
    end
end

function qsub(n::Int; wdir=pwd(), timelimit::Int=10000, ram::Int=4,  kwargs...)
    addprocs(QSUB(n, wdir, timelimit, ram); kwargs...)
end