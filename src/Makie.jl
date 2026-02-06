export makie

# Backend type definitions
abstract type MakieKey end
const MakieId = Any
const MakieIds = Vector{MakieId}
const MakieRef = GenericRef{MakieKey, MakieId}
const MakieRefs = Vector{MakieRef}
const MakieNativeRef = NativeRef{MakieKey, MakieId}

# Backend structure
@kwdef mutable struct MakieBackend <: Backend{MakieKey, MakieId}
  shapes::Shapes=Shape[]
  current_layer::Union{Nothing,AbstractLayer}=nothing
  layers::Dict{AbstractLayer,Vector{Shape}}=Dict{AbstractLayer,Vector{Shape}}()
  date::DateTime=DateTime(2020, 9, 21, 10, 0, 0)
  place::GeographicLocation=GeographicLocation(39, 9, 0, 0)
  render_env::RenderEnvironment=RealisticSkyEnvironment(5, true)
  ground_level::Float64=0.0
  ground_material::Union{Nothing,Material}=nothing
  view::View=top_view()
  # Makie scene objects
  figure::Union{Nothing,Figure}=nothing
  axis::Union{Nothing,Union{Axis,Axis3,LScene}}=nothing
  use_3d::Bool=true
  transaction::Parameter{KhepriBase.Transaction}=Parameter{KhepriBase.Transaction}(KhepriBase.AutoCommitTransaction())
  refs::References{MakieKey, MakieId}=References{MakieKey, MakieId}()
end

const MKE = MakieBackend

KhepriBase.backend_name(b::MKE) = "Makie"
KhepriBase.void_ref(b::MKE) = MakieNativeRef(nothing)

# Scene creation and management
function create_makie_scene_2d()
  fig = Figure(size=(800, 600))
  ax = Axis(fig[1,1], aspect=DataAspect())
  hidedecorations!(ax)
  fig, ax
end

function create_makie_scene_3d()
  fig = Figure(size=(800, 600))
  ax = LScene(fig[1,1], show_axis=false)
  fig, ax
end

function ensure_scene(b::MKE)
  if isnothing(b.figure) || isnothing(b.axis)
    if b.use_3d
      b.figure, b.axis = create_makie_scene_3d()
    else
      b.figure, b.axis = create_makie_scene_2d()
    end
    display(b.figure)
  end
  b.axis
end

export makie, update_view, clear_view, set_2d_mode, set_3d_mode

const makie = MKE()

update_view() = isnothing(makie.figure) || display(makie.figure)

function clear_view()
  if !isnothing(makie.axis)
    empty!(makie.axis)
  end
  update_view()
end

function set_2d_mode()
  makie.use_3d = false
  makie.figure = nothing
  makie.axis = nothing
end

function set_3d_mode()
  makie.use_3d = true
  makie.figure = nothing
  makie.axis = nothing
end

# Coordinate conversion
mkpoint(p) =
  let p = in_world(p)
    Point3f(p.x, p.y, p.z)
  end

mkpoint2(p) =
  let p = in_world(p)
    Point2f(p.x, p.y)
  end

mkpoints(ps) = [mkpoint(p) for p in ps]
mkpoints2(ps) = [mkpoint2(p) for p in ps]

# Color conversion
function mkcolor(mat)
  if isnothing(mat)
    :gray
  elseif mat isa RGBA
    RGBAf(mat.r, mat.g, mat.b, mat.alpha)
  elseif mat isa RGB
    RGBf(mat.r, mat.g, mat.b)
  else
    :gray
  end
end

# Primitives
KhepriBase.b_point(b::MKE, p, mat) =
  scatter!(ensure_scene(b), [mkpoint(p)], color=mkcolor(mat), markersize=5)

KhepriBase.b_line(b::MKE, ps, mat) =
  lines!(ensure_scene(b), mkpoints(ps), color=mkcolor(mat))

KhepriBase.b_polygon(b::MKE, ps, mat) =
  lines!(ensure_scene(b), mkpoints([ps..., ps[1]]), color=mkcolor(mat))

# Splines - approximate with line segments
function spline_points(ps, n=64)
  # Simple Catmull-Rom approximation
  length(ps) < 2 && return ps
  result = Loc[]
  for i in 1:length(ps)-1
    p0 = i > 1 ? ps[i-1] : ps[i]
    p1 = ps[i]
    p2 = ps[i+1]
    p3 = i < length(ps)-1 ? ps[i+2] : ps[i+1]
    for t in range(0, 1, length=n÷(length(ps)-1))
      # Catmull-Rom interpolation
      t2, t3 = t*t, t*t*t
      v = 0.5 * (2*p1 + (-p0 + p2)*t + (2*p0 - 5*p1 + 4*p2 - p3)*t2 + (-p0 + 3*p1 - 3*p2 + p3)*t3)
      push!(result, v)
    end
  end
  push!(result, ps[end])
  result
end

KhepriBase.b_spline(b::MKE, ps, v0, v1, mat) =
  lines!(ensure_scene(b), mkpoints(spline_points(ps)), color=mkcolor(mat))

KhepriBase.b_closed_spline(b::MKE, ps, mat) =
  let pts = spline_points([ps..., ps[1], ps[2]])
    lines!(ensure_scene(b), mkpoints(pts), color=mkcolor(mat))
  end

# Circle and arc using parametric sampling
function circle_points(c, r, n=64)
  [c + vpol(r, θ, c.cs) for θ in range(0, 2π, length=n+1)]
end

function arc_points(c, r, α, Δα, n=32)
  [c + vpol(r, θ, c.cs) for θ in range(α, α+Δα, length=max(2, abs(round(Int, n*Δα/(2π)))+1))]
end

KhepriBase.b_circle(b::MKE, c, r, mat) =
  lines!(ensure_scene(b), mkpoints(circle_points(c, r)), color=mkcolor(mat))

KhepriBase.b_arc(b::MKE, c, r, α, Δα, mat) =
  lines!(ensure_scene(b), mkpoints(arc_points(c, r, α, Δα)), color=mkcolor(mat))

# Rectangle
KhepriBase.b_rectangle(b::MKE, c, dx, dy, mat) =
  let p1 = c,
      p2 = add_x(c, dx),
      p3 = add_xy(c, dx, dy),
      p4 = add_y(c, dy)
    lines!(ensure_scene(b), mkpoints([p1, p2, p3, p4, p1]), color=mkcolor(mat))
  end

# Triangles and quads - using mesh
KhepriBase.b_trig(b::MKE, p1, p2, p3, mat) =
  let vertices = mkpoints([p1, p2, p3]),
      faces = [1 2 3]
    mesh!(ensure_scene(b), vertices, faces, color=mkcolor(mat))
  end

KhepriBase.b_quad(b::MKE, p1, p2, p3, p4, mat) =
  let vertices = mkpoints([p1, p2, p3, p4]),
      faces = [1 2 3; 1 3 4]  # Two triangles
    mesh!(ensure_scene(b), vertices, faces, color=mkcolor(mat))
  end

KhepriBase.b_ngon(b::MKE, ps, pivot, smooth, mat) =
  let n = length(ps),
      vertices = mkpoints([pivot, ps...]),
      faces = hcat([[1, i+1, i+2] for i in 1:n-1]..., [1, n+1, 2])'
    mesh!(ensure_scene(b), vertices, faces, color=mkcolor(mat))
  end

# Quad strips
KhepriBase.b_quad_strip(b::MKE, ps, qs, smooth, mat) =
  let n = length(ps),
      vertices = mkpoints([ps..., qs...]),
      faces = vcat([[i, i+1, n+i+1, n+i] for i in 1:n-1]...)
    # Convert to triangles
    tris = vcat([[f[1] f[2] f[3]; f[1] f[3] f[4]] for f in eachrow(reshape(faces, :, 4))]...)
    mesh!(ensure_scene(b), vertices, tris, color=mkcolor(mat))
  end

KhepriBase.b_quad_strip_closed(b::MKE, ps, qs, smooth, mat) =
  let n = length(ps),
      vertices = mkpoints([ps..., qs...]),
      quads = [[i, i%n+1, n+i%n+1, n+i] for i in 1:n],
      tris = vcat([[q[1] q[2] q[3]; q[1] q[3] q[4]] for q in quads]...)
    mesh!(ensure_scene(b), vertices, tris, color=mkcolor(mat))
  end

# Surfaces
KhepriBase.b_surface_polygon(b::MKE, ps, mat) =
  let n = length(ps)
    if n < 3
      return nothing
    elseif n == 3
      b_trig(b, ps[1], ps[2], ps[3], mat)
    else
      # Fan triangulation from first vertex
      vertices = mkpoints(ps)
      faces = hcat([[1, i, i+1] for i in 2:n-1]...)'
      mesh!(ensure_scene(b), vertices, faces, color=mkcolor(mat))
    end
  end

KhepriBase.b_surface_polygon_with_holes(b::MKE, ps, qss, mat) =
  # Simplified: just render outer polygon (holes require proper triangulation)
  b_surface_polygon(b, ps, mat)

KhepriBase.b_surface_circle(b::MKE, c, r, mat) =
  b_surface_polygon(b, circle_points(c, r, 64)[1:end-1], mat)

KhepriBase.b_surface_arc(b::MKE, c, r, α, Δα, mat) =
  let pts = arc_points(c, r, α, Δα)
    b_surface_polygon(b, [c, pts...], mat)
  end

KhepriBase.b_surface_rectangle(b::MKE, c, dx, dy, mat) =
  b_quad(b, c, add_x(c, dx), add_xy(c, dx, dy), add_y(c, dy), mat)

# Surface grid
KhepriBase.b_surface_grid(b::MKE, ptss, closed_u, closed_v, smooth_u, smooth_v, mat) =
  let (nu, nv) = size(ptss),
      vertices = mkpoints(vec(ptss)),
      idx(i, j) = (i-1)*nv + j,
      quads = [(idx(i,j), idx(i+1,j), idx(i+1,j+1), idx(i,j+1))
               for i in 1:(closed_u ? nu : nu-1)
               for j in 1:(closed_v ? nv : nv-1)],
      # Handle wraparound for closed surfaces
      wrap_i(i) = closed_u ? mod1(i, nu) : i,
      wrap_j(j) = closed_v ? mod1(j, nv) : j
    if isempty(quads)
      return nothing
    end
    tris = vcat([[q[1] q[2] q[3]; q[1] q[3] q[4]] for q in quads]...)
    mesh!(ensure_scene(b), vertices, tris, color=mkcolor(mat))
  end

# Closed spline surface
KhepriBase.b_surface_closed_spline(b::MKE, ps, mat) =
  let pts = spline_points([ps..., ps[1], ps[2]])[1:end-1]
    b_surface_polygon(b, pts, mat)
  end

# 3D Solids
KhepriBase.b_sphere(b::MKE, c, r, mat) =
  let u = range(0, 2π, length=32),
      v = range(0, π, length=16),
      x = [c.x + r * cos(θ) * sin(φ) for θ in u, φ in v],
      y = [c.y + r * sin(θ) * sin(φ) for θ in u, φ in v],
      z = [c.z + r * cos(φ) for θ in u, φ in v]
    surface!(ensure_scene(b), x, y, z, color=mkcolor(mat))
  end

KhepriBase.b_box(b::MKE, c, dx, dy, dz, mat) =
  let p = in_world(c),
      vx = in_world(vx(1, c.cs)),
      vy = in_world(vy(1, c.cs)),
      vz = in_world(vz(1, c.cs)),
      corners = [
        p, p+vx*dx, p+vx*dx+vy*dy, p+vy*dy,
        p+vz*dz, p+vx*dx+vz*dz, p+vx*dx+vy*dy+vz*dz, p+vy*dy+vz*dz
      ],
      vertices = mkpoints(corners),
      # 6 faces, each as 2 triangles
      faces = [
        1 2 3; 1 3 4;   # bottom
        5 8 7; 5 7 6;   # top
        1 5 6; 1 6 2;   # front
        4 3 7; 4 7 8;   # back
        1 4 8; 1 8 5;   # left
        2 6 7; 2 7 3;   # right
      ]
    mesh!(ensure_scene(b), vertices, faces, color=mkcolor(mat))
  end

KhepriBase.b_cylinder(b::MKE, cb, r, h, bmat, tmat, smat) =
  let n = 32,
      bottom = circle_points(cb, r, n)[1:end-1],
      top = [add_z(p, h) for p in bottom],
      all_pts = [bottom..., top...],
      vertices = mkpoints(all_pts),
      # Side faces
      side_quads = [(i, mod1(i+1, n), n+mod1(i+1, n), n+i) for i in 1:n],
      side_tris = vcat([[q[1] q[2] q[3]; q[1] q[3] q[4]] for q in side_quads]...),
      # Bottom cap (fan from center)
      center_b = length(all_pts) + 1,
      center_t = length(all_pts) + 2
    # Add center points
    vertices = vcat(vertices, [mkpoint(cb), mkpoint(add_z(cb, h))])
    bottom_tris = hcat([[center_b, i, mod1(i, n)+1] for i in 1:n]...)'
    top_tris = hcat([[center_t, n+mod1(i, n)+1, n+i] for i in 1:n]...)'
    all_tris = vcat(side_tris, bottom_tris, top_tris)
    mesh!(ensure_scene(b), vertices, all_tris, color=mkcolor(smat))
  end

KhepriBase.b_cone(b::MKE, cb, r, h, bmat, smat) =
  let n = 32,
      bottom = circle_points(cb, r, n)[1:end-1],
      apex = add_z(cb, h),
      vertices = mkpoints([bottom..., cb, apex]),
      center_idx = n + 1,
      apex_idx = n + 2,
      # Side triangles
      side_tris = hcat([[i, mod1(i, n)+1, apex_idx] for i in 1:n]...)',
      # Bottom cap
      bottom_tris = hcat([[center_idx, mod1(i, n)+1, i] for i in 1:n]...)'
    mesh!(ensure_scene(b), vertices, vcat(side_tris, bottom_tris), color=mkcolor(smat))
  end

KhepriBase.b_cone_frustum(b::MKE, cb, rb, h, rt, bmat, tmat, smat) =
  if rt ≈ 0
    b_cone(b, cb, rb, h, bmat, smat)
  else
    let n = 32,
        bottom = circle_points(cb, rb, n)[1:end-1],
        top = [add_z(p, h) for p in circle_points(cb, rt, n)[1:end-1]],
        vertices = mkpoints([bottom..., top..., cb, add_z(cb, h)]),
        center_b = 2n + 1,
        center_t = 2n + 2,
        # Side quads as triangles
        side_quads = [(i, mod1(i, n)+1, n+mod1(i, n)+1, n+i) for i in 1:n],
        side_tris = vcat([[q[1] q[2] q[3]; q[1] q[3] q[4]] for q in side_quads]...),
        # Caps
        bottom_tris = hcat([[center_b, mod1(i, n)+1, i] for i in 1:n]...)',
        top_tris = hcat([[center_t, n+i, n+mod1(i, n)+1] for i in 1:n]...)'
      mesh!(ensure_scene(b), vertices, vcat(side_tris, bottom_tris, top_tris), color=mkcolor(smat))
    end
  end

# Text
KhepriBase.b_text(b::MKE, str, p, size, mat) =
  text!(ensure_scene(b), mkpoint(p), text=str, fontsize=size, color=mkcolor(mat))

# View and rendering
KhepriBase.b_set_view(b::MKE, camera, target, lens, aperture) =
  # For LScene, we can set camera position
  if !isnothing(b.axis) && b.axis isa LScene
    cam = cameracontrols(b.axis.scene)
    update_cam!(b.axis.scene, cam, mkpoint(camera), mkpoint(target))
  end

KhepriBase.b_get_view(b::MKE) =
  (xyz(0, 0, 10), xyz(0, 0, 0), 50.0)

KhepriBase.b_zoom_extents(b::MKE) =
  if !isnothing(b.axis) && b.axis isa LScene
    # Makie auto-fits, but we can reset
    center!(b.axis.scene)
  end

KhepriBase.b_render_view(b::MKE, path) =
  if !isnothing(b.figure)
    save(path, b.figure)
    path
  end

KhepriBase.b_render_and_save_view(b::MKE, path) =
  b_render_view(b, path)

# Delete operations
KhepriBase.b_delete_all_shape_refs(b::MKE) =
  begin
    if !isnothing(b.axis)
      empty!(b.axis)
    end
    nothing
  end

# Layer operations (minimal implementation)
KhepriBase.b_layer(b::MKE, name, active, color) = name

KhepriBase.b_current_layer_ref(b::MKE) = "default"

KhepriBase.b_current_layer_ref(b::MKE, layer) = layer

KhepriBase.b_delete_all_shapes_in_layer(b::MKE, layer) = nothing

# Materials (visualization backend - colors only)
KhepriBase.b_new_material(b::MKE, name, base_color, metallic, specular, roughness,
                          clearcoat, clearcoat_roughness, ior, transmission,
                          transmission_roughness, emission_color, emission_strength) =
  base_color  # Just return the color for visualization

KhepriBase.b_plastic_material(b::MKE, name, color, roughness) = color
KhepriBase.b_metal_material(b::MKE, name, color, roughness, ior) = color
KhepriBase.b_glass_material(b::MKE, name, color, roughness, ior) = color
KhepriBase.b_mirror_material(b::MKE, name, color) = color

# Connection lifecycle
KhepriBase.after_connecting(b::MKE) = nothing
