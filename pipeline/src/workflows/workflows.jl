module Workflows

using ..Domain

include("acquisition_workflow.jl")
include("download_workflow.jl")

export AcquisitionResult, acquire_recordings
export DownloadResult, download_recordings

end
