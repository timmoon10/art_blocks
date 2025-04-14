module Geometry

import Random

mutable struct Rectangle

    min_x::Int
    max_x::Int
    min_y::Int
    max_y::Int

    color::Vector{Float64}

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
        throw("Too many rectangles for search space")
    end

    # Randomly pick rectangle corners
    corners = Set{Tuple{Int, Int}}()
    sizehint!(corners, num_rectangles)
    while length(corners) < num_rectangles
        rand = Random.rand(1:search_size)
        corner = divrem(rand - 1, search_y)
        push!(corners, corner)
    end

    # Construct rectangles
    out = Vector{Rectangle}()
    sizehint!(out, num_rectangles)
    for (min_x, min_y) in corners
        color = Random.rand(Float64, 3)
        rect = Rectangle(min_x, min_x + dim_x, min_y, min_y + dim_y, color)
        push!(out, rect)
    end

    return out
end

end  # module Geometry
