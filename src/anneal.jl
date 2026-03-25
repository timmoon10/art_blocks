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
end

function AnnealConfig(;
    color_space::Color.ColorSpace = Color.Oklab(),
    sigma::Float64                = 0.1,
    pos_step::Int                 = 5,
    size_step::Int                = 3,
    color_step::Float64           = 0.05,
    temperature::Float64          = 0.0,
    steps_per_frame::Int          = 50,
    )::AnnealConfig
    return AnnealConfig(color_space, sigma, pos_step, size_step, color_step, temperature, steps_per_frame)
end

# Block reward: sum of exp(-dist/σ) over all covered pixels, where dist is the
# Euclidean distance in the objective color space between the block's solid color
# and each image pixel. Larger blocks score more if they cover well; uncovered
# pixels implicitly score zero. We store the negative as cost so that SA
# minimization corresponds to maximizing total reward.
function block_cost(rect::Geometry.Rectangle, csi::Color.ColorSpaceImage, sigma::Float64)::Float64
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
        reward += exp(-sqrt(d1*d1 + d2*d2 + d3*d3) / sigma)
    end
    return -reward
end

function init_costs(
    rectangles::Vector{Geometry.Rectangle},
    csi::Color.ColorSpaceImage,
    config::AnnealConfig,
    )::Vector{Float64}
    return [block_cost(r, csi, config.sigma) for r in rectangles]
end

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

# Perform one SA step. Picks a random block, jitters it, and accepts or rejects
# the move. costs is updated in-place for accepted moves.
# Returns the index of the accepted block, or 0 if the move was rejected.
function anneal_step!(
    rectangles::Vector{Geometry.Rectangle},
    csi::Color.ColorSpaceImage,
    config::AnnealConfig,
    costs::Vector{Float64},
    min_x::Int, max_x::Int, min_y::Int, max_y::Int,
    )::Int
    idx      = Random.rand(1:length(rectangles))
    rect     = rectangles[idx]
    old_cost = costs[idx]
    saved    = _jitter!(rect, min_x, max_x, min_y, max_y, config)
    new_cost = block_cost(rect, csi, config.sigma)

    delta  = new_cost - old_cost
    accept = delta <= 0 ||
        (config.temperature > 0 && Random.rand() < exp(-delta / config.temperature))

    if accept
        costs[idx] = new_cost
        return idx
    else
        _revert!(rect, saved)
        return 0
    end
end

end  # module Anneal
