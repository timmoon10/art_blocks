module Color

import ImageCore
import Statistics

function image_to_color_space(
    image::Matrix,
    )::Array{Float64, 3}
    return Float64.(ImageCore.channelview(image))
end

# Returns the mean RGB color of the image region covered by a rectangle.
# color_space is a (3, height, width) array as returned by image_to_color_space.
# rect coordinates are 0-based; image indices are 1-based.
function average_rect_color(
    color_space::Array{Float64, 3},
    min_x::Int, max_x::Int,
    min_y::Int, max_y::Int,
    )::NTuple{3, Float64}
    height = size(color_space, 2)
    width  = size(color_space, 3)
    row_range = clamp(min_y + 1, 1, height):clamp(max_y, 1, height)
    col_range = clamp(min_x + 1, 1, width):clamp(max_x, 1, width)
    region = @view color_space[:, row_range, col_range]
    return (
        Statistics.mean(@view region[1, :, :]),
        Statistics.mean(@view region[2, :, :]),
        Statistics.mean(@view region[3, :, :]),
    )
end

end  # module Color
