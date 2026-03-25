import ArgParse
import FileIO

root_dir::String = dirname(@__DIR__)
include(joinpath(root_dir, "src", "ArtBlocks.jl"))

function parse_args()
    settings = ArgParse.ArgParseSettings()
    @ArgParse.add_arg_table settings begin
        "--num-rectangles"
            arg_type = Int
            default = 64
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

    # Initialize random rectangles
    rectangles = ArtBlocks.Geometry.make_random_rectangles(
        args["num-rectangles"],
        0,
        size(image, 2),
        0,
        size(image, 1),
    )

    # Anneal
    plotter = ArtBlocks.Plot.Plotter(image, rectangles)
    ArtBlocks.Plot.anneal!(plotter)

end

# Run main function
main()
