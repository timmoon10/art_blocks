import ArgParse
import FileIO

root_dir::String = dirname(@__DIR__)
include(joinpath(root_dir, "src", "ArtBlocks.jl"))

function parse_args()
    settings = ArgParse.ArgParseSettings()
    @ArgParse.add_arg_table settings begin
        "image_file"
            default = joinpath(root_dir, "starry_night.jpg")
    end
    return ArgParse.parse_args(settings)
end

function main()

    # Parse command-line arguments
    args = parse_args()

    # Load image
    image = FileIO.load(args["image_file"])
    image = FileIO.rotr90(image)

    # Plot image
    plotter = ArtBlocks.Plotter(image, [])
    ArtBlocks.plot(plotter)

end

# Run main function
main()
