module Color

import ImageCore
import Statistics

abstract type ColorSpace end
struct SRGB  <: ColorSpace end
struct Oklab <: ColorSpace end

struct ColorSpaceImage{CS <: ColorSpace}
    data::Array{Float64, 3}
end

# ── sRGB ↔ linear (IEC 61966-2-1) ───────────────────────────────────────────

_linearize(c::Float64)    = c <= 0.04045   ? c / 12.92 : ((c + 0.055) / 1.055)^2.4
_gamma_encode(c::Float64) = c <= 0.0031308 ? 12.92 * c : 1.055 * c^(1.0/2.4) - 0.055

# ── sRGB ↔ Oklab ────────────────────────────────────────────────────────────

function srgb_to_oklab(r::Float64, g::Float64, b::Float64)::NTuple{3, Float64}
    rl, gl, bl = _linearize(r), _linearize(g), _linearize(b)

    l = 0.4122214708*rl + 0.5363325363*gl + 0.0514459929*bl
    m = 0.2119034982*rl + 0.6806995451*gl + 0.1073969566*bl
    s = 0.0883024619*rl + 0.2817188376*gl + 0.6299787005*bl

    l_, m_, s_ = cbrt(l), cbrt(m), cbrt(s)

    L  =  0.2104542553*l_ + 0.7936177850*m_ - 0.0040720468*s_
    a  =  1.9779984951*l_ - 2.4285922050*m_ + 0.4505937099*s_
    b_ =  0.0259040371*l_ + 0.7827717662*m_ - 0.8086757660*s_

    return (L, a, b_)
end

function oklab_to_srgb(L::Float64, a::Float64, b::Float64)::NTuple{3, Float64}
    l_ = L + 0.3963377774*a + 0.2158037573*b
    m_ = L - 0.1055613458*a - 0.0638541728*b
    s_ = L - 0.0894841775*a - 1.2914855480*b

    l, m, s = l_^3, m_^3, s_^3

    rl =  4.0767416621*l - 3.3077115913*m + 0.2309699292*s
    gl = -1.2684380046*l + 2.6097574011*m - 0.3413193965*s
    bl = -0.0041960863*l - 0.7034186147*m + 1.7076147010*s

    return (
        clamp(_gamma_encode(rl), 0.0, 1.0),
        clamp(_gamma_encode(gl), 0.0, 1.0),
        clamp(_gamma_encode(bl), 0.0, 1.0),
    )
end

# ── ColorSpaceImage construction ─────────────────────────────────────────────

function image_to_color_space(image::Matrix, ::SRGB)::ColorSpaceImage{SRGB}
    return ColorSpaceImage{SRGB}(Float64.(ImageCore.channelview(image)))
end

function image_to_color_space(image::Matrix, ::Oklab = Oklab())::ColorSpaceImage{Oklab}
    srgb = Float64.(ImageCore.channelview(image))
    height, width = size(srgb, 2), size(srgb, 3)
    lab = similar(srgb)
    for j in 1:width, i in 1:height
        L, a, b = srgb_to_oklab(srgb[1,i,j], srgb[2,i,j], srgb[3,i,j])
        lab[1,i,j], lab[2,i,j], lab[3,i,j] = L, a, b
    end
    return ColorSpaceImage{Oklab}(lab)
end

# ── Averaging ────────────────────────────────────────────────────────────────

# Returns the mean sRGB color of the image region covered by a rectangle.
# rect coordinates are 0-based; image indices are 1-based.
function average_rect_color(
    csi::ColorSpaceImage,
    min_x::Int, max_x::Int,
    min_y::Int, max_y::Int,
    )::NTuple{3, Float64}
    height = size(csi.data, 2)
    width  = size(csi.data, 3)
    row_range = clamp(min_y + 1, 1, height):clamp(max_y, 1, height)
    col_range = clamp(min_x + 1, 1, width):clamp(max_x, 1, width)
    region = @view csi.data[:, row_range, col_range]
    c1 = Statistics.mean(@view region[1, :, :])
    c2 = Statistics.mean(@view region[2, :, :])
    c3 = Statistics.mean(@view region[3, :, :])
    return from_colorspace(c1, c2, c3, colorspace(csi))
end

# Convert an sRGB color into a given color space, and back.
to_colorspace(r::Float64, g::Float64, b::Float64, ::SRGB)  = (r, g, b)
to_colorspace(r::Float64, g::Float64, b::Float64, ::Oklab) = srgb_to_oklab(r, g, b)

from_colorspace(c1::Float64, c2::Float64, c3::Float64, ::SRGB)  = (c1, c2, c3)
from_colorspace(c1::Float64, c2::Float64, c3::Float64, ::Oklab) = oklab_to_srgb(c1, c2, c3)

colorspace(::ColorSpaceImage{CS}) where CS = CS()

colorspace_label(::ColorSpaceImage{SRGB})  = "srgb"
colorspace_label(::ColorSpaceImage{Oklab}) = "oklab"

end  # module Color
