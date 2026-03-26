module Anneal

import Random
import ..Color
import ..Geometry

struct AnnealConfig
    color_space::Color.ColorSpace  # color space for the objective function
    sigma::Float64                 # distance scale for the reward function
    pos_step::Int                  # max position jitter (pixels)
    size_step::Int                 # max size jitter (pixels)
    color_step::Float64            # max color jitter per channel (0–1)
    temperature::Float64           # SA temperature; 0 = greedy hill-climbing
    steps_per_frame::Int           # SA steps to run between display updates
    baseline_interval::Int         # SA steps between baseline recomputations; 0 disables
end

function AnnealConfig(;
    color_space::Color.ColorSpace = Color.Oklab(),
    sigma::Float64                = 0.1,
    pos_step::Int                 = 5,
    size_step::Int                = 3,
    color_step::Float64           = 0.05,
    temperature::Float64          = 0.0,
    steps_per_frame::Int          = 50,
    baseline_interval::Int        = 50,
    )::AnnealConfig
    return AnnealConfig(color_space, sigma, pos_step, size_step, color_step, temperature, steps_per_frame, baseline_interval)
end

# ── Coverage map ─────────────────────────────────────────────────────────────

# coverage_map[row, col] = number of blocks currently covering that pixel.
function init_coverage_map(
    rectangles::Vector{Geometry.Rectangle},
    height::Int, width::Int,
    )::Matrix{Int}
    coverage_map = zeros(Int, height, width)
    for rect in rectangles
        _update_coverage!(coverage_map, rect, 1)
    end
    return coverage_map
end

# Rebuild coverage_map in-place (e.g. after a reset).
function rebuild_coverage_map!(
    coverage_map::Matrix{Int},
    rectangles::Vector{Geometry.Rectangle},
    )
    fill!(coverage_map, 0)
    for rect in rectangles
        _update_coverage!(coverage_map, rect, 1)
    end
end

function _update_coverage!(
    coverage_map::Matrix{Int},
    rect::Geometry.Rectangle,
    delta::Int,
    )
    height, width = size(coverage_map)
    row_range = clamp(rect.min_y + 1, 1, height):clamp(rect.max_y, 1, height)
    col_range = clamp(rect.min_x + 1, 1, width):clamp(rect.max_x, 1, width)
    @view(coverage_map[row_range, col_range]) .+= delta
end

# ── Block area ────────────────────────────────────────────────────────────────

# Pixel area of a rectangle clipped to the image bounds.
function _block_area(rect::Geometry.Rectangle, height::Int, width::Int)::Int
    row_range = clamp(rect.min_y + 1, 1, height):clamp(rect.max_y, 1, height)
    col_range = clamp(rect.min_x + 1, 1, width):clamp(rect.max_x, 1, width)
    return length(row_range) * length(col_range)
end

# ── Objective ─────────────────────────────────────────────────────────────────

# Block reward: sum over covered pixels of exp(-dist/σ) / coverage_count.
# Dividing by coverage_count splits each pixel's reward among all blocks
# covering it, discouraging overlap. Returns the negative as cost so that SA
# minimization corresponds to maximizing total reward.
#
# The caller is responsible for removing this block from the coverage map
# before calling, so the block does not compete with itself.
function block_cost(
    rect::Geometry.Rectangle,
    csi::Color.ColorSpaceImage,
    coverage_map::Matrix{Int},
    sigma::Float64,
    )::Float64
    bc     = Color.to_colorspace(rect.color..., Color.colorspace(csi))
    height = size(csi.data, 2)
    width  = size(csi.data, 3)
    row_range = clamp(rect.min_y + 1, 1, height):clamp(rect.max_y, 1, height)
    col_range = clamp(rect.min_x + 1, 1, width):clamp(rect.max_x, 1, width)
    reward = 0.0
    for j in col_range, i in row_range
        d1 = bc[1] - csi.data[1, i, j]
        d2 = bc[2] - csi.data[2, i, j]
        d3 = bc[3] - csi.data[3, i, j]
        reward += exp(-sqrt(d1*d1 + d2*d2 + d3*d3) / sigma) / (coverage_map[i, j] + 1)
    end
    return -reward
end

# Total reward of the current configuration, computed with all blocks in the
# coverage map. Intended for display; not used in the SA accept/reject step.
function total_reward(
    rectangles::Vector{Geometry.Rectangle},
    csi::Color.ColorSpaceImage,
    coverage_map::Matrix{Int},
    sigma::Float64,
    )::Float64
    return sum(-block_cost(r, csi, coverage_map, sigma) for r in rectangles)
end

# Baseline reward per block-pixel: total reward divided by total block area
# (counting overlapping pixels once per block). Used to give each pixel an
# opportunity cost so that blocks neither greedily expand nor shrink.
function compute_baseline(
    rectangles::Vector{Geometry.Rectangle},
    csi::Color.ColorSpaceImage,
    coverage_map::Matrix{Int},
    sigma::Float64,
    )::Float64
    height = size(csi.data, 2)
    width  = size(csi.data, 3)
    T = total_reward(rectangles, csi, coverage_map, sigma)
    A = sum(_block_area(r, height, width) for r in rectangles)
    return A > 0 ? T / A : 0.0
end

# ── Jitter ────────────────────────────────────────────────────────────────────

# Jitter a rectangle in-place and return the previous state for potential revert.
function _jitter!(
    rect::Geometry.Rectangle,
    min_x::Int, max_x::Int, min_y::Int, max_y::Int,
    config::AnnealConfig,
    )
    saved = (rect.min_x, rect.max_x, rect.min_y, rect.max_y, rect.color)

    new_width  = clamp(
        rect.max_x - rect.min_x + Random.rand(-config.size_step:config.size_step),
        1, max_x - min_x,
    )
    new_height = clamp(
        rect.max_y - rect.min_y + Random.rand(-config.size_step:config.size_step),
        1, max_y - min_y,
    )
    new_min_x = clamp(
        rect.min_x + Random.rand(-config.pos_step:config.pos_step),
        min_x, max_x - new_width,
    )
    new_min_y = clamp(
        rect.min_y + Random.rand(-config.pos_step:config.pos_step),
        min_y, max_y - new_height,
    )

    rect.min_x = new_min_x
    rect.max_x = new_min_x + new_width
    rect.min_y = new_min_y
    rect.max_y = new_min_y + new_height

    c1, c2, c3 = Color.to_colorspace(rect.color..., config.color_space)
    rect.color = Color.from_colorspace(
        c1 + (Random.rand() * 2 - 1) * config.color_step,
        c2 + (Random.rand() * 2 - 1) * config.color_step,
        c3 + (Random.rand() * 2 - 1) * config.color_step,
        config.color_space,
    )

    return saved
end

function _revert!(rect::Geometry.Rectangle, saved)
    rect.min_x, rect.max_x, rect.min_y, rect.max_y, rect.color = saved
end

# ── SA step ───────────────────────────────────────────────────────────────────

# Perform one SA step. Picks a random block, removes it from the coverage map,
# then evaluates old and new costs on the same footing (no self-competition).
# Accepts or rejects the move and updates the coverage map accordingly.
# Returns the index of the accepted block, or 0 if rejected.
function anneal_step!(
    rectangles::Vector{Geometry.Rectangle},
    csi::Color.ColorSpaceImage,
    config::AnnealConfig,
    coverage_map::Matrix{Int},
    min_x::Int, max_x::Int, min_y::Int, max_y::Int,
    baseline::Float64 = 0.0,
    )::Int
    idx  = Random.rand(1:length(rectangles))
    rect = rectangles[idx]
    height, width = size(coverage_map)

    _update_coverage!(coverage_map, rect, -1)
    old_cost = block_cost(rect, csi, coverage_map, config.sigma) +
               baseline * _block_area(rect, height, width)
    saved    = _jitter!(rect, min_x, max_x, min_y, max_y, config)
    new_cost = block_cost(rect, csi, coverage_map, config.sigma) +
               baseline * _block_area(rect, height, width)

    delta  = new_cost - old_cost
    accept = delta <= 0 ||
        (config.temperature > 0 && Random.rand() < exp(-delta / config.temperature))

    if accept
        _update_coverage!(coverage_map, rect, +1)
        return idx
    else
        _revert!(rect, saved)
        _update_coverage!(coverage_map, rect, +1)
        return 0
    end
end

end  # module Anneal
