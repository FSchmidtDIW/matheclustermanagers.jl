module MatheClusterManagers

using Distributed
using ProgressMeter

import Distributed: launch, manage, kill, init_worker, connect

worker_arg() = `--worker=$(Distributed.init_multi(); cluster_cookie())`

include("qsub.jl")
include("qrsh.jl")

end
