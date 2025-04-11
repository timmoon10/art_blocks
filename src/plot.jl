import GLMakie

mutable struct Rectangle

    min_x::Int64
    max_x::Int64
    min_y::Int64
    max_y::Int64

    color::Vector{Float64}

end

mutable struct Plotter

    # Target image
    image::Array

    # Rectangles
    rectangles::Vector{Rectangle}

end

function plot(plotter::Plotter)

    # Initialize plot
    fig = GLMakie.Figure()
    ax = GLMakie.Axis(fig[1, 1], aspect=GLMakie.DataAspect())
    GLMakie.empty!(ax)
    GLMakie.hidespines!(ax)
    GLMakie.hidedecorations!(ax)

    # Plot image
    GLMakie.image!(ax, plotter.image)

    for rect in plotter.rectangles
        coords = [
            (rect.min_x, rect.min_y),
            (rect.max_x, rect.min_y),
            (rect.max_x, rect.max_y),
            (rect.min_x, rect.max_y),
        ]
        color = GLMakie.RGBf(rect.color[1], rect.color[2], rect.color[3])
        GLMakie.poly!(coords, color=color)
    end

    # Display image
    GLMakie.display(fig)

    # Stall by waiting for user input
    println("Press enter to exit...")
    readline()

end
