# ImageSDF.jl
# ==============================================================================
# JIT GPU-ACCELERATED IMAGE -> NONLINEAR SDF PARAMETER CONVERSION
# ==============================================================================
# GRUG: This cave converts raw image binary into SDF (Signed Distance Field)
# parameter arrays that image nodes can use as their pattern signal.
# All arrays are ROW-ALIGNED: xArray[i] aligns with yArray[i], brightnessArray[i], colorArray[i].
# Key values get a PINEAL DRIP jitter every time they fire (run from bullseye, snap back).
# Temporal coherence uses timestep as meta-geometry to organize alignments.
# ==============================================================================

module ImageSDF

using Random

export detect_image_binary, image_to_sdf_params, SDFParams, apply_sdf_jitter
export TemporalCoherenceRecord, update_temporal_coherence!, sdf_to_signal

# ==============================================================================
# ERROR TYPES - GRUG: NO SILENT FAILURES!
# ==============================================================================

struct ImageSDFError <: Exception
    msg::String
end

struct ImageBinaryDetectionError <: Exception
    msg::String
end

Base.showerror(io::IO, e::ImageSDFError) =
    print(io, "ImageSDFError: ", e.msg)
Base.showerror(io::IO, e::ImageBinaryDetectionError) =
    print(io, "ImageBinaryDetectionError: ", e.msg)

# ==============================================================================
# SDF PARAMETER STRUCT
# ==============================================================================

# GRUG: All arrays are ROW-ALIGNED. Index i in all arrays = same pixel.
# xArray[i], yArray[i], brightnessArray[i], colorArray[i] all describe pixel i.
struct SDFParams
    xArray::Vector{Float64}          # GRUG: Normalized x position [0.0, 1.0]
    yArray::Vector{Float64}          # GRUG: Normalized y position [0.0, 1.0]
    brightnessArray::Vector{Float64} # GRUG: Brightness value [0.0, 1.0]
    colorArray::Vector{Float64}      # GRUG: Color scalar (hue-derived) [0.0, 1.0]
    width::Int                       # GRUG: Original image width in pixels
    height::Int                      # GRUG: Original image height in pixels
    timestamp::Float64               # GRUG: When this SDF was born (for temporal coherence)
end

# ==============================================================================
# TEMPORAL COHERENCE RECORD
# ==============================================================================

# GRUG: Time step is meta-geometry! Grug use timestamps to organize SDF alignments.
# When SDF params fire at similar timesteps, they are temporally coherent.
mutable struct TemporalCoherenceRecord
    sdf_id::String
    last_fired::Float64              # GRUG: Unix timestamp of last activation
    fire_count::Int                  # GRUG: How many times this SDF has fired
    avg_interval::Float64            # GRUG: Rolling average interval between fires
    coherence_score::Float64         # GRUG: How temporally stable this SDF is [0.0, 1.0]
end

# GRUG: Keep a global temporal coherence ledger so Grug can track SDF timing patterns.
const TEMPORAL_COHERENCE_LEDGER = Dict{String, TemporalCoherenceRecord}()
const TCL_LOCK = ReentrantLock()

# GRUG: Update the temporal coherence record for an SDF when it fires.
function update_temporal_coherence!(sdf_id::String)::Float64
    if strip(sdf_id) == ""
        throw(ImageSDFError("!!! FATAL: Cannot update temporal coherence for empty SDF id! !!!"))
    end

    now_t = time()

    lock(TCL_LOCK) do
        if haskey(TEMPORAL_COHERENCE_LEDGER, sdf_id)
            rec = TEMPORAL_COHERENCE_LEDGER[sdf_id]
            interval = now_t - rec.last_fired

            # GRUG: Rolling average update. New avg = (old avg * count + new interval) / (count + 1)
            rec.fire_count += 1
            rec.avg_interval = (rec.avg_interval * (rec.fire_count - 1) + interval) / rec.fire_count
            rec.last_fired = now_t

            # GRUG: Coherence score = stability of intervals. 
            # If intervals are very regular, score -> 1.0. Chaotic -> 0.0.
            # Use inverse coefficient of variation as coherence proxy.
            if rec.avg_interval > 0.0
                # GRUG: Low variance around mean = high coherence. 
                # Bounded between 0.1 and 1.0 so Grug never fully loses coherence.
                variance_proxy = abs(interval - rec.avg_interval) / rec.avg_interval
                rec.coherence_score = clamp(1.0 - variance_proxy, 0.1, 1.0)
            end

            return rec.coherence_score
        else
            # GRUG: First fire! Create record with baseline coherence.
            TEMPORAL_COHERENCE_LEDGER[sdf_id] = TemporalCoherenceRecord(
                sdf_id, now_t, 1, 0.0, 0.5
            )
            return 0.5
        end
    end
end

# ==============================================================================
# IMAGE BINARY DETECTION (REGEX-BASED)
# ==============================================================================

# GRUG: Regex patterns for detecting image binary in messages.
# Grug look for Base64-encoded image data URIs and raw binary magic bytes.
# These are the most common ways image data arrives in text messages.

# GRUG: Base64 image data URI pattern (e.g. "data:image/png;base64,iVBORw0KGgo...")
const BASE64_IMAGE_REGEX = r"data:image/(?:png|jpeg|jpg|gif|webp|bmp);base64,([A-Za-z0-9+/=]{64,})"

# GRUG: PNG magic bytes in hex string representation (89504E47...)
const PNG_HEX_REGEX = r"(?:^|[^A-Fa-f0-9])89504[Ee]47(?:[A-Fa-f0-9]{2}){4,}"

# GRUG: JPEG magic bytes (FFD8FF...)
const JPEG_HEX_REGEX = r"(?:^|[^A-Fa-f0-9])[Ff][Ff][Dd]8[Ff][Ff](?:[A-Fa-f0-9]{2}){4,}"

# GRUG: Raw binary blob marker (often used in protocol buffers or custom formats)
const RAW_BINARY_REGEX = r"\\x89PNG|\\xFF\\xD8\\xFF"

"""
detect_image_binary(input::String)::Tuple{Bool, Symbol, String}

GRUG: Sniff the input for image binary. Returns (found, format, extracted_data).
format is :base64, :hex_png, :hex_jpeg, :raw, or :none.
extracted_data is the raw image payload string if found, else "".
NO SILENT FAILURES: throws ImageBinaryDetectionError on malformed input.
"""
function detect_image_binary(input::String)::Tuple{Bool, Symbol, String}
    if strip(input) == ""
        throw(ImageBinaryDetectionError(
            "!!! FATAL: detect_image_binary got empty input string! !!!"
        ))
    end

    # GRUG: Check Base64 data URI first (most common, most structured)
    m = match(BASE64_IMAGE_REGEX, input)
    if !isnothing(m)
        return (true, :base64, String(m.captures[1]))
    end

    # GRUG: Check PNG hex dump
    m = match(PNG_HEX_REGEX, input)
    if !isnothing(m)
        return (true, :hex_png, String(m.match))
    end

    # GRUG: Check JPEG hex dump
    m = match(JPEG_HEX_REGEX, input)
    if !isnothing(m)
        return (true, :hex_jpeg, String(m.match))
    end

    # GRUG: Check raw binary escape sequences
    m = match(RAW_BINARY_REGEX, input)
    if !isnothing(m)
        return (true, :raw, String(m.match))
    end

    # GRUG: No image found. Not an error, just no image.
    return (false, :none, "")
end

# ==============================================================================
# JIT IMAGE -> NONLINEAR SDF CONVERSION
# ==============================================================================

"""
image_to_sdf_params(image_data::Vector{UInt8}, width::Int, height::Int)::SDFParams

GRUG: The heart of JIT GPU-style conversion. Takes raw image bytes, returns SDFParams.
All output arrays are ROW-ALIGNED (xArray[i] aligns with yArray[i] etc).
Uses nonlinear SDF math: distances are computed relative to pixel intensity gradients.
This simulates GPU-parallel processing by vectorizing over all pixels.
"""
function image_to_sdf_params(image_data::Vector{UInt8}, width::Int, height::Int)::SDFParams
    if isempty(image_data)
        throw(ImageSDFError("!!! FATAL: image_to_sdf_params got empty image_data! !!!"))
    end
    if width <= 0 || height <= 0
        throw(ImageSDFError(
            "!!! FATAL: image_to_sdf_params got invalid dimensions: $(width)x$(height)! !!!"
        ))
    end

    # GRUG: Expected minimum bytes = width * height (grayscale).
    # If image is RGB, it's 3x that. We accept both and normalize.
    expected_gray = width * height
    expected_rgb  = width * height * 3
    expected_rgba = width * height * 4

    channels = if length(image_data) >= expected_rgba
        4
    elseif length(image_data) >= expected_rgb
        3
    elseif length(image_data) >= expected_gray
        1
    else
        throw(ImageSDFError(
            "!!! FATAL: image_data length $(length(image_data)) too small for $(width)x$(height)! !!!"
        ))
    end

    n_pixels = width * height

    # GRUG: Pre-allocate all row-aligned arrays. Row alignment means pixel i maps to
    # xArray[i], yArray[i], brightnessArray[i], colorArray[i] simultaneously.
    xArray          = Vector{Float64}(undef, n_pixels)
    yArray          = Vector{Float64}(undef, n_pixels)
    brightnessArray = Vector{Float64}(undef, n_pixels)
    colorArray      = Vector{Float64}(undef, n_pixels)

    # GRUG: Walk every pixel. Compute row (y) and column (x) from linear index.
    for i in 1:n_pixels
        row = (i - 1) ÷ width   # GRUG: 0-based row index
        col = (i - 1) % width   # GRUG: 0-based col index

        # GRUG: Normalize spatial coordinates to [0.0, 1.0]
        xArray[i] = col / max(width  - 1, 1)
        yArray[i] = row / max(height - 1, 1)

        # GRUG: Extract brightness and color from image data based on channel count
        base_idx = (i - 1) * channels + 1
        if base_idx > length(image_data)
            throw(ImageSDFError(
                "!!! FATAL: Pixel index out of range at pixel $i, base_idx $base_idx! !!!"
            ))
        end

        if channels == 1
            # GRUG: Grayscale. Brightness = the single channel.
            brightness = Float64(image_data[base_idx]) / 255.0
            brightnessArray[i] = brightness
            colorArray[i] = brightness  # GRUG: No color info, use brightness as color scalar
        elseif channels == 3
            # GRUG: RGB. Brightness = luminance formula. Color = hue proxy from R-B spread.
            r = Float64(image_data[base_idx])     / 255.0
            g = Float64(image_data[base_idx + 1]) / 255.0
            b = Float64(image_data[base_idx + 2]) / 255.0
            # GRUG: Standard luminance weights (ITU-R BT.709)
            brightnessArray[i] = 0.2126 * r + 0.7152 * g + 0.0722 * b
            # GRUG: Simple hue proxy: R-B difference, normalized [0.0, 1.0]
            colorArray[i] = clamp((r - b + 1.0) / 2.0, 0.0, 1.0)
        elseif channels == 4
            # GRUG: RGBA. Same as RGB but skip alpha for brightness/color.
            r = Float64(image_data[base_idx])     / 255.0
            g = Float64(image_data[base_idx + 1]) / 255.0
            b = Float64(image_data[base_idx + 2]) / 255.0
            brightnessArray[i] = 0.2126 * r + 0.7152 * g + 0.0722 * b
            colorArray[i] = clamp((r - b + 1.0) / 2.0, 0.0, 1.0)
        end
    end

    # GRUG: Apply nonlinear SDF transformation.
    # Instead of linear distances, use a sigmoid-like function to emphasize
    # edges (high gradient regions) and suppress flat regions.
    brightnessArray = _apply_nonlinear_sdf_transform(brightnessArray, width, height)

    return SDFParams(
        xArray, yArray, brightnessArray, colorArray,
        width, height,
        time()  # GRUG: Stamp the birth time for temporal coherence
    )
end

"""
_apply_nonlinear_sdf_transform(brightness::Vector{Float64}, width::Int, height::Int)::Vector{Float64}

GRUG: Core nonlinear SDF transform. Compute local gradient magnitude for each pixel
using a simple 3x3 Sobel-like kernel. High gradient = edge = high SDF activation.
This is the "nonlinear" part of the nonlinear SDF - edges pop, flat regions recede.
"""
function _apply_nonlinear_sdf_transform(
    brightness::Vector{Float64}, width::Int, height::Int
)::Vector{Float64}
    n = length(brightness)
    if n != width * height
        throw(ImageSDFError(
            "!!! FATAL: brightness array size $n != width*height=$(width*height)! !!!"
        ))
    end

    sdf_out = Vector{Float64}(undef, n)

    for i in 1:n
        row = (i - 1) ÷ width
        col = (i - 1) % width

        # GRUG: Simple finite difference gradient approximation.
        # Grug look at neighbors. If Grug at edge of image, clamp to boundary.
        row_up   = max(row - 1, 0)
        row_down = min(row + 1, height - 1)
        col_left = max(col - 1, 0)
        col_right = min(col + 1, width - 1)

        idx_up    = row_up   * width + col + 1
        idx_down  = row_down * width + col + 1
        idx_left  = row * width + col_left  + 1
        idx_right = row * width + col_right + 1

        # GRUG: Gradient magnitude approximation (central difference)
        gx = brightness[idx_right] - brightness[idx_left]
        gy = brightness[idx_down]  - brightness[idx_up]
        grad_mag = sqrt(gx * gx + gy * gy)

        # GRUG: Nonlinear sigmoid-like activation on gradient.
        # Strong edges get activated strongly. Flat areas get suppressed.
        # tanh maps gradient magnitude [0, ~1.4] to [0, ~0.99]
        sdf_out[i] = tanh(grad_mag * 3.0)
    end

    return sdf_out
end

# ==============================================================================
# SDF JITTER (PINEAL DRIP MODULATION)
# ==============================================================================

"""
apply_sdf_jitter(params::SDFParams)::SDFParams

GRUG: Every time SDF fires, key values get a slight jitter (pineal drip modulation).
They run slightly from the bullseye then snap back to baseline.
This is the same principle as slight_jitter in PatternScanner but applied to
the full SDF parameter arrays for temporal coherence texture.
"""
function apply_sdf_jitter(params::SDFParams)::SDFParams
    if isempty(params.xArray)
        throw(ImageSDFError("!!! FATAL: apply_sdf_jitter received empty SDFParams! !!!"))
    end

    n = length(params.xArray)

    # GRUG: Generate a single small random offset for this fire event.
    # Pineal drip: slight deviation, then snap back. We model the deviation here;
    # the snap-back is implicit since next call starts fresh from stored values.
    jitter_magnitude = 0.008 + (0.004 * rand())  # GRUG: Small bounded jitter [0.008, 0.012]

    # GRUG: Apply per-element bounded jitter. Different pixel gets slightly different shake.
    jitter_brightness = [clamp(b + (rand() * 2.0 - 1.0) * jitter_magnitude, 0.0, 1.0)
                         for b in params.brightnessArray]
    jitter_color      = [clamp(c + (rand() * 2.0 - 1.0) * jitter_magnitude * 0.5, 0.0, 1.0)
                         for c in params.colorArray]

    # GRUG: Spatial coords (x, y) get minimal jitter to avoid spatial drift.
    jitter_x = [clamp(x + (rand() * 2.0 - 1.0) * jitter_magnitude * 0.1, 0.0, 1.0)
                for x in params.xArray]
    jitter_y = [clamp(y + (rand() * 2.0 - 1.0) * jitter_magnitude * 0.1, 0.0, 1.0)
                for y in params.yArray]

    return SDFParams(
        jitter_x, jitter_y, jitter_brightness, jitter_color,
        params.width, params.height,
        params.timestamp  # GRUG: Preserve original birth timestamp, jitter doesn't change birth!
    )
end

# ==============================================================================
# SDF -> FLAT SIGNAL VECTOR (FOR PATTERN SCANNER COMPATIBILITY)
# ==============================================================================

"""
sdf_to_signal(params::SDFParams; max_samples::Int=256)::Vector{Float64}

GRUG: Convert SDFParams into a flat Float64 signal vector compatible with PatternScanner.
Grug cannot feed 4 arrays of 10,000 pixels into the scanner directly (cave fire!).
So Grug samples max_samples pixels uniformly, then interleaves [x, y, brightness, color]
for each sampled pixel. Result is a signal of length (4 * max_samples).
"""
function sdf_to_signal(params::SDFParams; max_samples::Int=256)::Vector{Float64}
    if isempty(params.xArray)
        throw(ImageSDFError("!!! FATAL: sdf_to_signal received empty SDFParams! !!!"))
    end
    if max_samples <= 0
        throw(ImageSDFError(
            "!!! FATAL: sdf_to_signal max_samples must be > 0, got $max_samples! !!!"
        ))
    end

    n_pixels = length(params.xArray)
    # GRUG: Sample uniformly. If fewer pixels than max_samples, just use all pixels.
    sample_count = min(max_samples, n_pixels)
    step = max(1, n_pixels ÷ sample_count)

    # GRUG: Pre-allocate output signal: 4 values per sampled pixel (x, y, brightness, color)
    signal = Vector{Float64}(undef, sample_count * 4)

    out_idx = 1
    for i in 1:step:(step * sample_count)
        pixel_i = min(i, n_pixels)  # GRUG: Safety clamp
        signal[out_idx]     = params.xArray[pixel_i]
        signal[out_idx + 1] = params.yArray[pixel_i]
        signal[out_idx + 2] = params.brightnessArray[pixel_i]
        signal[out_idx + 3] = params.colorArray[pixel_i]
        out_idx += 4
    end

    return signal
end

# ==============================================================================
# BASE64 -> RAW BYTES HELPER
# ==============================================================================

"""
base64_to_bytes(b64_str::String)::Vector{UInt8}

GRUG: Decode a Base64 string into raw bytes for image_to_sdf_params.
Uses Julia's built-in base64decode. Throws ImageSDFError on failure.
"""
function base64_to_bytes(b64_str::String)::Vector{UInt8}
    if strip(b64_str) == ""
        throw(ImageSDFError("!!! FATAL: base64_to_bytes got empty string! !!!"))
    end
    try
        return base64decode(b64_str)
    catch e
        throw(ImageSDFError("!!! FATAL: base64_to_bytes failed to decode: $e !!!"))
    end
end

end # module ImageSDF

# ==============================================================================
# ARCHITECTURAL SPECIFICATION: IMAGE SDF LAYER
#
# 1. ROW-ALIGNED PARAMETER ARRAYS:
# All SDFParams arrays (xArray, yArray, brightnessArray, colorArray) are strictly
# row-aligned. Index i in all arrays maps to the same source pixel. This enables
# vectorized pattern matching in PatternScanner without index misalignment errors.
#
# 2. NONLINEAR SDF TRANSFORM:
# Raw brightness is transformed via a Sobel-like gradient magnitude + tanh activation.
# This creates edge-emphasized, flat-suppressed representations that capture structural
# image features (edges, textures) rather than raw pixel values. Edges become
# high-activation zones; uniform regions fade to near-zero.
#
# 3. PINEAL DRIP JITTER (TEMPORAL COHERENCE TEXTURE):
# apply_sdf_jitter() injects small bounded per-element noise every time an SDF fires.
# This models biological sensor noise (slightly different retinal activation each view)
# while preserving structural identity. TemporalCoherenceRecord tracks firing intervals
# to measure whether SDF activations are rhythmically stable.
#
# 4. JIT COMPATIBILITY:
# sdf_to_signal() bridges SDFParams -> PatternScanner-compatible Float64 vectors.
# Uniform subsampling (max 256 pixels by default) keeps signal size bounded while
# preserving representative spatial structure.
#
# 5. REGEX-BASED IMAGE DETECTION:
# detect_image_binary() uses multi-pattern regex matching to identify Base64 data URIs,
# PNG/JPEG hex dumps, and raw binary escape sequences. This is the gating mechanism
# for /mission and /grow commands to route image inputs to image nodes.
# ==============================================================================