module MatheClusterManagers

using Distributed
using ProgressMeter

import Distributed: launch, manage, kill, init_worker, connect

worker_cookie() = begin Distributed.init_multi(); cluster_cookie() end
worker_arg() = `--worker=$(worker_cookie())`


include("qsub.jl")
include("qrsh.jl")

end
