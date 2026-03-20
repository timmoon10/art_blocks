module Plot

import GLMakie

import ..Geometry

mutable struct Plotter

    # Target image
    image::Array

    # Rectangles
    rectangles::Vector{Geometry.Rectangle}

    # Animation settings
    frame_time::Float64
    step_size::Int

end

function Plotter(
    image::Array,
    rectangles::Vector{Geometry.Rectangle};
    frame_time::Float64 = 1/30,
    step_size::Int = 5,
    )::Plotter
    return Plotter(image, rectangles, frame_time, step_size)
end

function draw_frame!(ax, plotter::Plotter)

    GLMakie.empty!(ax)

    # Draw target image
    GLMakie.image!(ax, plotter.image)

    # Draw rectangles
    for rect in plotter.rectangles
        coords = [
            (rect.min_y, rect.min_x),
            (rect.max_y, rect.min_x),
            (rect.max_y, rect.max_x),
            (rect.min_y, rect.max_x),
        ]
        color = GLMakie.RGBAf(rect.color..., rect.alpha)
        GLMakie.poly!(coords, color=color)
    end

end

function plot(plotter::Plotter)

    fig = GLMakie.Figure()
    ax = GLMakie.Axis(fig[1, 1], aspect=GLMakie.DataAspect())
    GLMakie.hidespines!(ax)
    GLMakie.hidedecorations!(ax)

    draw_frame!(ax, plotter)
    GLMakie.display(fig)

    println("Press enter to exit...")
    readline()

end

# Returns the four corner coordinates of a rectangle as a vector of Point2f.
function rect_coords(rect::Geometry.Rectangle)::Vector{GLMakie.Point2f}
    return [
        GLMakie.Point2f(rect.min_y, rect.min_x),
        GLMakie.Point2f(rect.max_y, rect.min_x),
        GLMakie.Point2f(rect.max_y, rect.max_x),
        GLMakie.Point2f(rect.min_y, rect.max_x),
    ]
end

function animate!(plotter::Plotter)

    max_y = size(plotter.image, 1)
    max_x = size(plotter.image, 2)

    fig = GLMakie.Figure()
    ax = GLMakie.Axis(fig[1, 1], aspect=GLMakie.DataAspect())
    GLMakie.hidespines!(ax)
    GLMakie.hidedecorations!(ax)

    # Image is static — draw it once
    GLMakie.image!(ax, plotter.image)

    # Each rectangle gets one Observable for its vertex positions.
    # Updating the observable triggers GLMakie's rendering thread to redraw
    # that polygon without touching any other scene state.
    coord_obs = [GLMakie.Observable(rect_coords(r)) for r in plotter.rectangles]
    for (rect, obs) in zip(plotter.rectangles, coord_obs)
        color = GLMakie.RGBAf(rect.color..., rect.alpha)
        GLMakie.poly!(ax, obs, color=color)
    end

    screen = GLMakie.display(fig)

    while isopen(screen)
        Geometry.jiggle!(
            plotter.rectangles, 0, max_x, 0, max_y,
            step_size=plotter.step_size,
        )
        for (rect, obs) in zip(plotter.rectangles, coord_obs)
            obs[] = rect_coords(rect)
        end
        sleep(plotter.frame_time)
    end

end

end  # module Plot
