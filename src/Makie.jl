export makie

abstract type MakieKey end
const MakieId = Any
const MakieIds = Vector{MakieId}
const MakieRef = GenericRef{MakieKey, MakieId}
const MakieRefs = Vector{MakieRef}
const MakieNativeRef = NativeRef{MakieKey, MakieId}

create_makie_scene() =
  let scene = Scene(clear=true, visible=true, backgroundcolor=:white, resolution=(50,50)),
      fig = Figure(scene=scene, resolution=(50,50)),
      axis = Axis(fig[1,1])
    hidedecorations!(axis)
    display(scene)
    axis
  end

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
    target::Axis=create_makie_scene()
    refs::References{MakieKey, MakieId}=References{MakieKey, MakieId}()
  end

const MKE = MakieBackend

KhepriBase.void_ref(b::MKE) = MakieNativeRef(nothing)
KhepriBase.realization_type(::Type{MKE}) = EagerRealization()

const makie = MKE()

export update_makie_view
update_makie_view() =
  display(makie.target.scene)


KhepriBase.backend_name(b::MKE) = "Makie"

KhepriBase.after_connecting(b::MKE) =
  begin
    #set_material()
  end

mkpoint(p) = 
  let p = in_world(p)
    Point3f0(p.x, p.y, p.z)
  end

KhepriBase.b_point(b::MKE, p, mat) =
  scatter!(b.target, mkpoint(p))

KhepriBase.b_line(b::MKE, ps, mat) =
  lines!(b.target, map(mkpoint, ps))

#=KhepriBase.b_polygon(b::MKE, ps, mat) =
  lines!(b.target, map(mkpoint, [ps..., ps[1]]))

KhepriBase.b_spline(b::MKE, ps, v0, v1, mat) =
  if (v0 == false) && (v1 == false)
    #Makie_hobby_spline(b.target, ps, false)
    Makie_spline(b.target, ps, false)
  elseif (v0 != false) && (v1 != false)
    MakieInterpSpline(b.target, ps, v0, v1)
  else
    MakieInterpSpline(b.target,
                     ps,
                     v0 == false ? ps[2] - ps[1] : v0,
                     v1 == false ? ps[end-1] - ps[end] : v1)
  end

KhepriBase.b_closed_spline(b::MKE, ps, mat) =
  Makie_hobby_closed_spline(b.target, ps)

KhepriBase.b_circle(b::MKE, c, r, mat) =
  withMakieXForm(b, c) do out, cc
    Makie_circle(out, cc, r)
  end

KhepriBase.b_arc(b::MKE, c, r, α, Δα, mat) =
  withMakieXForm(b, c) do out, cc
    Makie_maybe_arc(out, cc, r, α, Δα, false, mat)
  end

KhepriBase.b_rectangle(b::MKE, c, dx, dy, mat) =
  withMakieXForm(b, c) do out, cc
    Makie_rectangle(out, cc, dx, dy)
  end

# KhepriBase.b_trig(b::MKE, p1, p2, p3, mat) =
#   Makie_closed_line(b.target, [p1, p2, p3], true)

#
# KhepriBase.b_trig(b::MKE, p1, p2, p3, mat) =
#   let io = b.target
#     println(io, raw"\addplot3[patch,table/row sep=\\,patch table={")
#     println(io, "0 1 2 \\")
#     println(io, raw")}] table [row sep=\\] {")
#      x y z c\\
#      0 1 0 0\\
#      0 0 -1 0\\
#      -1 0 0 0\\
#      0 0 1 0\\
#      1 0 0 0\\
#     };
#
# KhepriBase.b_quad(b::MKE, p1, p2, p3, p4, mat) =
#   Makie_closed_line(b.target, [p1, p2, p3, p4], true)

# KhepriBase.b_trig(b::MKE, p1, p2, p3, mat) =
#   let io = b.target
#     print(io, raw"\addplot3[patch,shader=interp] coordinates {")
#     Makie_3d_coord(io, p1)
#     Makie_3d_coord(io, p2)
#     Makie_3d_coord(io, p3)
#     println(io, "};")
#   end

# surfaces need to be saved so that they can be sorted
KhepriBase.b_trig(b::MKE, p1, p2, p3, mat) =
  begin
    push!(b.target, (p1, p2, p3, mat))
    nothing
  end

# To better map to Makie, we also provide a non-portable specialized version of Makie paths

KhepriBase.@defshape(Shape1D, Makie_path, args::Vector=[])
Makie_path(arg, args...) = Makie_path([arg, args...])

struct MakieNode
  p1::Loc
  p2::Loc
  label::String
  options::String
end

macro n_str(label)
  :($label, $options)
end

Makie_path([x(1),x(2), n"sin(x)", "below"),
=#


paint_trig(b::MKE, (p1, p2, p3, mat)) =
  let io = b.target,
      #c = trig_center(p1, p2, p3),
      n = trig_normal(p1, p2, p3),
      v = rotate_vector(b.view.target - b.view.camera, vz(1), pi/4),
      α = round(Int, angle_between(n, v)/pi*100)
    #if α > 0.5
    print(io, "\\fill[black!$(α)!white] ")
    #print(io, "\\fill[gray, opacity=$α] ")
    Makie_3d_coord(io, p1)
    print(io, "--")
    Makie_3d_coord(io, p2)
    print(io, "--")
    Makie_3d_coord(io, p3)
    println(io, "--cycle;")
  #end
end

KhepriBase.b_quad(b::MKE, p1, p2, p3, p4, mat) =
  #Makie_closed_line(b.target, [p1, p2, p3, p4])
  invoke(b_quad, Tuple{Backend, Any, Any, Any, Any, Any}, b, p1, p2, p3, p4, mat)
  # let io = b.target
  #   print(io, raw"\addplot3[patch,shader=interp] coordinates {")
  #   Makie_3d_coord(io, p1)
  #   Makie_3d_coord(io, p2)
  #   Makie_3d_coord(io, p3)
  #   Makie_3d_coord(io, p4)
  #   println(io, "};")
  # end

KhepriBase.b_surface_polygon(b::MKE, ps, mat) =
  Makie_closed_line(b.target, ps, true)
  #=

KhepriBase.b_surface_polygon_with_holes(b::MKE, ps, qss, mat) =
  Makie_closed_lines(b.target, [ps, qss...], true)

KhepriBase.b_surface_circle(b::MKE, c, r, mat) =
  withMakieXForm(b, c) do out, cc
    Makie_circle(out, cc, r, true)
  end

KhepriBase.b_surface_arc(b::MKE, c, r, α, Δα, mat) =
  withMakieXForm(b, c) do out, cc
    Makie_maybe_arc(out, cc, r, α, Δα, true)
  end
=#
# realize(b::MKE, s::Ellipse) =
#   withMakieXForm(b, s.center) do out, c
#     Makie_ellipse(out, c, s.radius_x, s.radius_y, 0, false)
#   end
#
# realize(b::MKE, s::SurfaceEllipse) =
#   withMakieXForm(b, s.center) do out, c
#     Makie_ellipse(out, c, s.radius_x, s.radius_y, 0, true)
#   end
#
# realize(b::MKE, s::EllipticArc) =
#   error("Finish this")

#realize(b::MKE, s::SurfaceElliptic_Arc) = MakieCircle(b.target,

# KhepriBase.b_surface_rectangle(b::MKE, c, dx, dy, mat) =
#   withMakieXForm(b, c) do out, cc
#     Makie_rectangle(out, cc, dx, dy, true)
#   end

KhepriBase.b_text(b::MKE, str, p, size, mat) =
  #invoke(b_text, Tuple{Backend, Any, Any, Any, Any}, b, str, p, size, mat)
  withMakieXForm(b, p) do out, c
    Makie_text(out, str, c, size)
  end

KhepriBase.b_dim_line(b::MKE, p, q, tv, str, size, outside, mat) =
  #invoke(b_dim_line, Tuple{Backend, Any, Any, Any, Any, Any, Any, Any}, b, p, q, tv, str, size, outside, mat)
  Makie_dim_line(b.target, p, q, str, outside)

KhepriBase.b_ext_line(b::MKE, p, q, mat) =
  Makie_line(b.target, [p, q], "illustration")

KhepriBase.b_render_view(b::MKE, path) =
    save(path, b.target.scene)
#=
# Illustrations
KhepriBase.b_textify(b::MKE, expr) = latexify(expr)

KhepriBase.b_labels(b::MKE, p, strs, mat) =
  withMakieXForm(b, p) do out, c
    Makie_node(out, c, "",
      "fill,circle,outer sep=0,inner sep=0,minimum size=2pt,illustration,"*
      join(["label={[illustration]$ϕ:$str}" for (str,ϕ) in zip(strs, division(-45, 315, length(strs), false))], ","))
  end

KhepriBase.b_radii_illustration(b::MKE, c, rs, rs_txts, mat) =
  withMakieXForm(b, c) do out, cc
    for (r, r_txt, ϕ) in zip(rs, rs_txts, division(π/6, 2π+π/6, length(rs), false))
      Makie_line(out, [c, c+vpol(r, ϕ)], "latex-latex,illustration")
      Makie_node(out, intermediate_loc(c, c + vpol(r, ϕ)), "", "outer sep=0,inner sep=0,label={[outer sep=0,inner sep=0,illustration]$(rad2deg(ϕ+π/2)):$r_txt}")
    end
  end

KhepriBase.b_vectors_illustration(b::MKE, p, a, rs, rs_txts, mat) =
  withMakieXForm(b, p) do out, c
    for (r, r_txt) in zip(rs, rs_txts)
      Makie_line(out, [c, c+vpol(r, a)], "latex-latex,illustration")
      Makie_node(out, intermediate_loc(c, c + vpol(r, a)), "", "outer sep=0,inner sep=0,label={[illustration]$(rad2deg(a-π/2)):$r_txt}")
    end
  end

KhepriBase.b_angles_illustration(b::MKE, c, rs, ss, as, r_txts, s_txts, a_txts, mat) =
  withMakieXForm(b, c) do out, cc
    let maxr = maximum(rs),
        n = length(rs),
        ars = division(0.2maxr, 0.7maxr, n, false),
        idxs = sortperm(as),
        (rs, ss, as, r_txts, s_txts, a_txts) = (rs[idxs], ss[idxs], as[idxs], r_txts[idxs], s_txts[idxs], a_txts[idxs])
      for (r, ar, s, a, r_txt, s_txt, a_txt) in zip(rs, ars, ss, as, r_txts, s_txts, a_txts)
        if !(r ≈ 0.0)
          if !(s ≈ 0.0)
            Makie_line(out, [c, c+vpol(ar, 0)], "illustration")
            Makie_maybe_arc(out, c, ar, 0, s, false, "-latex,illustration")
            Makie_node(out, c + vpol(ar, s/2), "", "outer sep=0,inner sep=0,label={[outer sep=0,inner sep=0,illustration]$(rad2deg(s/2)):$s_txt}")
          end
          if !(a ≈ 0.0)
            Makie_line(out, [c, c+vpol(ar, s)], "illustration")
            Makie_line(out, [c, c+vpol(r, s + a)], "-latex,illustration")
            (a > 0.0) ?
              Makie_maybe_arc(out, c, ar, s, a, false, "-latex,illustration") :
              Makie_maybe_arc(out, c, ar, s, a, false, "latex-,illustration")
            Makie_node(out, c + vpol(ar, s + a/2), "", "outer sep=0,inner sep=0,label={[outer sep=0,inner sep=0,illustration]$(rad2deg(s + a/2)):$a_txt}")
          else
            Makie_line(out, [c, c+vpol(maxr, a)], "-latex,illustration")
          end
        end
        Makie_node(out, intermediate_loc(c, c + vpol(maxr, s + a)), "", "inner sep=0,label={[outer sep=0,inner sep=0,illustration]$(rad2deg(s + a - π/2)):$r_txt}")
      end
    end
  end

KhepriBase.b_arcs_illustration(b::MKE, c, rs, ss, as, r_txts, s_txts, a_txts, mat) =
  withMakieXForm(b, c) do out, cc
    let maxr = maximum(rs),
        n = length(rs),
        ars = division(0.2maxr, 0.7maxr, n, false),
        idxs = sortperm(ss),
        (rs, ss, as, r_txts, s_txts, a_txts) = (rs[idxs], ss[idxs], as[idxs], r_txts[idxs], s_txts[idxs], a_txts[idxs])
      for (i, r, ar, s, a, r_txt, s_txt, a_txt) in zip(1:n, rs, ars, ss, as, r_txts, s_txts, a_txts)
        if !(r ≈ 0.0)
          if !(s ≈ 0.0) && ((i == 1) || !(s ≈ ss[i-1] + as[i-1]))
            Makie_line(out, [c, c+vpol(ar, 0)], "illustration")
            Makie_maybe_arc(out, c, ar, 0, s, false, "-latex,illustration")
            Makie_node(out, c + vpol(ar, s/2), "", "outer sep=0,inner sep=0,label={[outer sep=0,inner sep=0,illustration]$(rad2deg(s/2)):$s_txt}")
          end
          if !(a ≈ 0.0)
            #let ar = ((i == 1) || !(s ≈ ss[i-1] + as[i-1])) ? ar : ars[i-1]
            Makie_line(out, [c, c+vpol(maxr, s)], "illustration")
            Makie_line(out, [c, c+vpol(maxr, s + a)], "-latex,illustration")
            Makie_maybe_arc(out, c, ar, s, a, false, "-latex,illustration")
            Makie_node(out, c + vpol(ar, s + a/2), "", "outer sep=0,inner sep=0,label={[outer sep=0,inner sep=0,illustration]$(rad2deg(s + a/2)):$a_txt}")
          end
          Makie_node(out, intermediate_loc(c, c + vpol(maxr, s + a)), "", "outer sep=0,inner sep=0,label={[outer sep=0,inner sep=0,illustration]$(rad2deg(s + a - π/2)):$r_txt}")
        end
      end
    end
  end
=#