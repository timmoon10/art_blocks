import ImageCore

function image_to_color_space(
    image::Matrix,
    )::Array{Float64, 3}
    return Float64.(ImageCore.channelview(image))
end
