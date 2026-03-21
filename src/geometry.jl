module Geometry

import Random

mutable struct Rectangle

    min_x::Int
    max_x::Int
    min_y::Int
    max_y::Int

    color::NTuple{3, Float64}
    alpha::Float64

end

# Mean rectangle dimensions for a given canvas and number of rectangles.
function _mean_dims(num_rectangles::Int, min_x::Int, max_x::Int, min_y::Int, max_y::Int)
    mean_dim_x = max(ceil(Int, (max_x - min_x) / sqrt(num_rectangles)), 1)
    mean_dim_y = max(ceil(Int, (max_y - min_y) / sqrt(num_rectangles)), 1)
    return mean_dim_x, mean_dim_y
end

function _random_rect(
    mean_dim_x::Int, mean_dim_y::Int,
    min_x::Int, max_x::Int, min_y::Int, max_y::Int,
    )::Rectangle
    dim_x = Random.rand(1:min(2 * mean_dim_x - 1, max_x - min_x))
    dim_y = Random.rand(1:min(2 * mean_dim_y - 1, max_y - min_y))
    cx = Random.rand(min_x:max(max_x - dim_x, min_x))
    cy = Random.rand(min_y:max(max_y - dim_y, min_y))
    color = (Random.rand(Float64), Random.rand(Float64), Random.rand(Float64))
    return Rectangle(cx, cx + dim_x, cy, cy + dim_y, color, 0.5)
end

function make_random_rectangles(
    num_rectangles::Int,
    min_x::Int,
    max_x::Int,
    min_y::Int,
    max_y::Int,
    )::Vector{Rectangle}

    mean_dim_x, mean_dim_y = _mean_dims(num_rectangles, min_x, max_x, min_y, max_y)

    out = Vector{Rectangle}()
    sizehint!(out, num_rectangles)
    for _ in 1:num_rectangles
        push!(out, _random_rect(mean_dim_x, mean_dim_y, min_x, max_x, min_y, max_y))
    end

    return out
end

function reset!(
    rectangles::Vector{Rectangle},
    min_x::Int,
    max_x::Int,
    min_y::Int,
    max_y::Int,
    )

    mean_dim_x, mean_dim_y = _mean_dims(length(rectangles), min_x, max_x, min_y, max_y)

    for rect in rectangles
        new_rect = _random_rect(mean_dim_x, mean_dim_y, min_x, max_x, min_y, max_y)
        rect.min_x = new_rect.min_x
        rect.max_x = new_rect.max_x
        rect.min_y = new_rect.min_y
        rect.max_y = new_rect.max_y
        rect.color = new_rect.color
    end

end

function jiggle!(
    rectangles::Vector{Rectangle},
    min_x::Int,
    max_x::Int,
    min_y::Int,
    max_y::Int;
    step_size::Int = 5,
    color_step::Float64 = 0.1,
    )

    for rect in rectangles
        # Jiggle dimensions
        new_width  = max(rect.max_x - rect.min_x + Random.rand(-step_size:step_size), 1)
        new_height = max(rect.max_y - rect.min_y + Random.rand(-step_size:step_size), 1)
        new_width  = min(new_width,  max_x - min_x)
        new_height = min(new_height, max_y - min_y)

        # Jiggle position
        dx = Random.rand(-step_size:step_size)
        dy = Random.rand(-step_size:step_size)
        new_min_x = clamp(rect.min_x + dx, min_x, max_x - new_width)
        new_min_y = clamp(rect.min_y + dy, min_y, max_y - new_height)

        rect.min_x = new_min_x
        rect.max_x = new_min_x + new_width
        rect.min_y = new_min_y
        rect.max_y = new_min_y + new_height

        # Jiggle color
        r, g, b = rect.color
        r = clamp(r + (Random.rand() * 2 - 1) * color_step, 0.0, 1.0)
        g = clamp(g + (Random.rand() * 2 - 1) * color_step, 0.0, 1.0)
        b = clamp(b + (Random.rand() * 2 - 1) * color_step, 0.0, 1.0)
        rect.color = (r, g, b)
    end

end

end  # module Geometry
