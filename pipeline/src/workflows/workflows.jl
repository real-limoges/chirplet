module Workflows

using ..Domain

include("acquisition_workflow.jl")

export AcquisitionResult, acquire_recordings

end
