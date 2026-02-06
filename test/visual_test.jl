# Visual test for KhepriMakie - actually renders shapes
# Run this interactively to see the output

using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using KhepriMakie
using KhepriBase

println("KhepriMakie Visual Test")
println("=======================")

# Set the backend
backend(makie)

println("Creating geometry...")

# Delete any existing shapes
delete_all_shapes()

# Create some 2D curves
println("- Lines and curves...")
line(xyz(0, 0, 0), xyz(5, 0, 0), xyz(5, 5, 0))
polygon(xyz(10, 0, 0), xyz(15, 0, 0), xyz(15, 5, 0), xyz(10, 5, 0))
circle(xyz(20, 2.5, 0), 2.5)
rectangle(xyz(25, 0, 0), 5, 5)

# Create surfaces
println("- Surfaces...")
surface_polygon(xyz(0, 10, 0), xyz(5, 10, 0), xyz(2.5, 15, 0))
surface_rectangle(xyz(10, 10, 0), 5, 5)
surface_circle(xyz(22.5, 12.5, 0), 2.5)

# Create 3D solids
println("- 3D Solids...")
sphere(xyz(5, 25, 5), 3)
box(xyz(15, 20, 0), 6, 6, 6)
cylinder(xyz(25, 23, 0), 2, xyz(25, 23, 8))
cone(xyz(35, 23, 0), 3, 8)
cone_frustum(xyz(45, 23, 0), 3, 6, 1.5)

println()
println("Geometry created!")
println("A figure window should appear with the rendered shapes.")
println()
println("Use update_view() to refresh the display.")
println("Use clear_view() to clear all geometry.")

# Force display update
update_view()

println("Done!")
