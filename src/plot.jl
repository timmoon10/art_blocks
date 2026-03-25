module Plot

import Base.Threads
import GLMakie

import ..Color
import ..Geometry

mutable struct Plotter

    # Target image
    image::Array

    # Rectangles
    rectangles::Vector{Geometry.Rectangle}

    # Animation settings
    frame_time::Float64
    step_size::Int

    # Color space used when averaging image pixels under each block
    color_space_img::Any  # Color.ColorSpaceImage{<:Color.ColorSpace}

end

function Plotter(
    image::Array,
    rectangles::Vector{Geometry.Rectangle};
    frame_time::Float64 = 1/30,
    step_size::Int = 5,
    )::Plotter
    return Plotter(image, rectangles, frame_time, step_size, Color.image_to_color_space(image))
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

    if Threads.nthreads() < 2
        @warn "animate! requires at least 2 threads for the command prompt. " *
              "Restart Julia with `--threads N` (N ≥ 2), or the prompt will not respond."
    end

    max_y = size(plotter.image, 1)
    max_x = size(plotter.image, 2)

    fig = GLMakie.Figure()
    ax = GLMakie.Axis(fig[1, 1], aspect=GLMakie.DataAspect())
    GLMakie.hidespines!(ax)
    GLMakie.hidedecorations!(ax)

    # Image is static — draw it once
    img_plot = GLMakie.image!(ax, plotter.image)

    # Each rectangle gets one Observable for its vertex positions and one for its color.
    # Updating these observables triggers GLMakie's rendering thread to redraw
    # that polygon without touching any other scene state.
    coord_obs = [GLMakie.Observable(rect_coords(r)) for r in plotter.rectangles]
    color_obs = [GLMakie.Observable(GLMakie.RGBAf(r.color..., r.alpha)) for r in plotter.rectangles]
    for (obs, cobs) in zip(coord_obs, color_obs)
        GLMakie.poly!(ax, obs, color=cobs)
    end

    function update_colors_from_image!()
        for (rect, cobs) in zip(plotter.rectangles, color_obs)
            rect.color = Color.average_rect_color(
                plotter.color_space_img, rect.min_x, rect.max_x, rect.min_y, rect.max_y,
            )
            cobs[] = GLMakie.RGBAf(rect.color..., rect.alpha)
        end
    end

    screen = GLMakie.display(fig)

    # Animation state — only ever read/written by the animation loop below,
    # so no locking needed.
    is_paused::Bool = false

    function print_help()
        println("\nCommands")
        println("--------")
        println("help                   show this message")
        println("info                   show current animation state")
        println("pause                  pause the animation")
        println("unpause                resume the animation")
        println("reset                  reset blocks to random positions, sizes, and colors")
        println("toggle image           show/hide the underlying image")
        println("color space <name>     set averaging color space (srgb, oklab)")
        println("exit                   close the window and exit")
    end

    function print_info()
        println("\nAnimation state")
        println("---------------")
        println("Paused:       ", is_paused)
        println("Rectangles:   ", length(plotter.rectangles))
        println("Step size:    ", plotter.step_size)
        println("Frame time:   ", round(plotter.frame_time * 1000, digits=1), " ms")
        println("Color space:  ", Color.colorspace_label(plotter.color_space_img))
    end

    function handle_command(line::String)
        command = lowercase(strip(line))
        if command == "help"
            print_help()
        elseif command == "info"
            print_info()
        elseif command == "pause"
            is_paused = true
            println("\nPaused.")
        elseif command == "unpause"
            is_paused = false
            println("\nUnpaused.")
        elseif startswith(command, "color space ")
            name = strip(command[length("color space ")+1:end])
            if name == "srgb"
                plotter.color_space_img = Color.image_to_color_space(plotter.image, Color.SRGB())
                update_colors_from_image!()
                println("\nColor space set to srgb.")
            elseif name == "oklab"
                plotter.color_space_img = Color.image_to_color_space(plotter.image, Color.Oklab())
                update_colors_from_image!()
                println("\nColor space set to oklab.")
            else
                println("\nUnknown color space: \"$name\". Available: srgb, oklab.")
            end
        elseif command == "toggle image"
            img_plot.visible[] = !img_plot.visible[]
            println("\nImage ", img_plot.visible[] ? "shown." : "hidden.")
        elseif command == "reset"
            Geometry.reset!(plotter.rectangles, 0, max_x, 0, max_y)
            update_colors_from_image!()
            for (rect, obs) in zip(plotter.rectangles, coord_obs)
                obs[] = rect_coords(rect)
            end
            println("\nReset.")
        elseif command == "exit"
            GLMakie.closeall()
        else
            println("\nUnknown command: \"$command\". Type \"help\" for a list of commands.")
        end
    end

    print_help()

    # Spawn a dedicated OS thread to read commands from stdin.
    # readline() is a blocking syscall, so it must live on its own thread —
    # if it ran on the animation thread it would freeze the animation.
    loop_active = Threads.Atomic{Bool}(true)
    command_channel = Channel{String}(32)
    Threads.@spawn begin
        while loop_active[]
            # Brief pause at the top of each iteration. On the first iteration
            # this lets print_help() finish before the prompt appears. On
            # subsequent iterations it lets the animation loop process the
            # previous command and print its response before the next prompt.
            sleep(0.01)
            print("Command: ")
            line = readline()
            isempty(strip(line)) || put!(command_channel, line)
        end
    end

    # Animation loop. Frame work (jiggle + observable update) runs at
    # frame_time intervals; command polling runs every 10 ms so that responses
    # are printed within ~10 ms of the command arriving, before the reader thread
    # wakes from its 10 ms sleep and prints the next prompt.
    last_frame_time = time()
    while isopen(screen) && loop_active[]

        now = time()
        if now - last_frame_time >= plotter.frame_time
            if !is_paused
                Geometry.jiggle!(
                    plotter.rectangles, 0, max_x, 0, max_y,
                    step_size=plotter.step_size,
                )
                update_colors_from_image!()
                for (rect, obs) in zip(plotter.rectangles, coord_obs)
                    obs[] = rect_coords(rect)
                end
            end
            last_frame_time = now
        end

        while isready(command_channel)
            handle_command(take!(command_channel))
        end

        sleep(0.01)
    end

    loop_active[] = false
    close(command_channel)

end

end  # module Plot
