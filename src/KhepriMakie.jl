module KhepriMakie
using KhepriBase
using Makie
using Makie: mesh!, lines!, scatter!, text!, surface!, poly!
using Makie: Figure, Axis, LScene, Axis3
using Makie: hidedecorations!, cameracontrols, update_cam!, center!
using Makie: Point2f, Point3f, RGBf, RGBAf
using CairoMakie
using Dates

# functions that need specialization
include(khepribase_interface_file())

include("Makie.jl")

function __init__()
    add_current_backend(makie)
end

end
  