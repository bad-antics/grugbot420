__precompile__(false)

module GrugBot420

# ==============================================================================
# GrugBot420 — Neuromorphic Cognitive Engine
# ==============================================================================
# A neuromorphic AI engine that models cognition through competing populations
# of pattern nodes. Many rocks compete to be loudest. Loudest rock gets to talk.
# Sometimes a quiet rock gets lucky (coinflip). That is how Grug think.
# ==============================================================================

using Distributions
using JSON
using Random
using Base.Threads: Atomic, atomic_add!, ReentrantLock
using Base64: base64decode

# --------------------------------------------------------------------------
# Submodule includes (order matters — upstream before downstream)
# --------------------------------------------------------------------------
include("stochastichelper.jl")
using .CoinFlipHeader

include("patternscanner.jl")
using .PatternScanner

include("ImageSDF.jl")
using .ImageSDF

include("EyeSystem.jl")
using .EyeSystem

include("SemanticVerbs.jl")
using .SemanticVerbs

include("ActionTonePredictor.jl")
using .ActionTonePredictor

include("LobeTable.jl")
using .LobeTable

include("Lobe.jl")
using .Lobe

include("BrainStem.jl")
using .BrainStem

include("Thesaurus.jl")
using .Thesaurus

include("InputQueue.jl")
using .InputQueue

include("ChatterMode.jl")
using .ChatterMode

include("PhagyMode.jl")
using .PhagyMode

include("engine.jl")
include("Main.jl")

# --------------------------------------------------------------------------
# Re-exports for public API
# --------------------------------------------------------------------------
export @coinflip, bias
export cheap_scan, medium_scan, high_res_scan
export detect_image_binary, image_to_sdf_params, SDFParams
export add_verb!, add_relation_class!, add_synonym!
export create_lobe!, connect_lobes!, lobe_grow!
export create_lobe_table!

end # module GrugBot420
