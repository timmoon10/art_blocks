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

function make_random_rectangles(
    num_rectangles::Int,
    min_x::Int,
    max_x::Int,
    min_y::Int,
    max_y::Int,
    )::Vector{Rectangle}

    # Rectangle dimensions
    dim_x = max(ceil(Int, (max_x - min_x) / sqrt(num_rectangles)), 1)
    dim_y = max(ceil(Int, (max_y - min_y) / sqrt(num_rectangles)), 1)

    # Search space
    search_x = max(max_x - min_x - (dim_x - 1), 1)
    search_y = max(max_y - min_y - (dim_y - 1), 1)
    search_size = search_x * search_y
    if search_size < num_rectangles
        throw(ArgumentError("Too many rectangles for search space"))
    end

    # Randomly pick rectangle corners
    corners = Set{Tuple{Int, Int}}()
    sizehint!(corners, num_rectangles)
    while length(corners) < num_rectangles
        idx = Random.rand(1:search_size)
        corner = divrem(idx - 1, search_y)
        push!(corners, corner)
    end

    # Construct rectangles
    out = Vector{Rectangle}()
    sizehint!(out, num_rectangles)
    for (cx, cy) in corners
        color = (Random.rand(Float64), Random.rand(Float64), Random.rand(Float64))
        rect = Rectangle(cx, cx + dim_x, cy, cy + dim_y, color, 0.5)
        push!(out, rect)
    end

    return out
end

function jiggle!(
    rectangles::Vector{Rectangle},
    min_x::Int,
    max_x::Int,
    min_y::Int,
    max_y::Int;
    step_size::Int = 5,
    )

    for rect in rectangles
        width = rect.max_x - rect.min_x
        height = rect.max_y - rect.min_y
        dx = Random.rand(-step_size:step_size)
        dy = Random.rand(-step_size:step_size)
        new_min_x = clamp(rect.min_x + dx, min_x, max_x - width)
        new_min_y = clamp(rect.min_y + dy, min_y, max_y - height)
        rect.min_x = new_min_x
        rect.max_x = new_min_x + width
        rect.min_y = new_min_y
        rect.max_y = new_min_y + height
    end

end

end  # module Geometry
