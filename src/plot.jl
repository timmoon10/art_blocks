import GLMakie

mutable struct Plotter

    # Target image
    image::Array

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

    # Display image
    GLMakie.display(fig)

    # Stall by waiting for user input
    println("Press enter to exit...")
    readline()

end
