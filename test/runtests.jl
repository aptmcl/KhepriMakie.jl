# KhepriMakie tests - Tests for Makie visualization backend

using KhepriMakie
using KhepriBase
using Makie: Point3f, RGBf, RGBAf
using Test

@testset "KhepriMakie.jl" begin

  @testset "Backend initialization" begin
    @test makie isa KhepriBase.Backend
    @test KhepriBase.backend_name(makie) == "Makie"
    @test KhepriBase.void_ref(makie) === 0
  end

  @testset "Backend fields" begin
    @test hasproperty(makie, :refs)
    @test makie.refs isa KhepriBase.References
    @test hasproperty(makie, :shapes)
    @test hasproperty(makie, :layers)
    @test hasproperty(makie, :view)
    @test hasproperty(makie, :figure)
    @test hasproperty(makie, :axis)
    @test hasproperty(makie, :use_3d)
    @test hasproperty(makie, :transaction)
  end

  @testset "Lazy initialization" begin
    fresh_backend = KhepriMakie.MakieBackend()
    @test isnothing(fresh_backend.figure)
    @test isnothing(fresh_backend.axis)
    @test fresh_backend.use_3d == true
  end

  @testset "Type system" begin
    @test isdefined(KhepriMakie, :MakieKey)
    @test isdefined(KhepriMakie, :MakieId)
    @test isdefined(KhepriMakie, :MakieRef)
    @test isdefined(KhepriMakie, :MakieNativeRef)
    @test KhepriMakie.MKE === KhepriMakie.MakieBackend
  end

  @testset "Helper functions" begin
    @test isdefined(KhepriMakie, :mkpoint)
    @test isdefined(KhepriMakie, :mkpoints)
    @test isdefined(KhepriMakie, :mkcolor)
    @test isdefined(KhepriMakie, :circle_points)
    @test isdefined(KhepriMakie, :arc_points)
    @test isdefined(KhepriMakie, :spline_points)
  end

  @testset "Scene management" begin
    @test isdefined(KhepriMakie, :create_makie_scene_2d)
    @test isdefined(KhepriMakie, :create_makie_scene_3d)
    @test isdefined(KhepriMakie, :ensure_scene)
    @test isdefined(KhepriMakie, :set_2d_mode)
    @test isdefined(KhepriMakie, :set_3d_mode)
    @test isdefined(KhepriMakie, :clear_view)
    @test isdefined(KhepriMakie, :update_view)
  end

  @testset "Render settings" begin
    @test hasproperty(makie, :date)
    @test hasproperty(makie, :place)
    @test hasproperty(makie, :render_env)
    @test hasproperty(makie, :ground_level)
  end

  @testset "Coordinate conversion" begin
    p = xyz(1.0, 2.0, 3.0)
    mp = KhepriMakie.mkpoint(p)
    @test mp isa Point3f
    @test mp[1] ≈ 1.0
    @test mp[2] ≈ 2.0
    @test mp[3] ≈ 3.0
  end

  @testset "Color conversion" begin
    @test KhepriMakie.mkcolor(nothing) == :gray
    @test KhepriMakie.mkcolor(rgb(1, 0, 0)) isa RGBf
    @test KhepriMakie.mkcolor(rgba(1, 0, 0, 0.5)) isa RGBAf
  end

  @testset "Circle points generation" begin
    c = xyz(0, 0, 0)
    pts = KhepriMakie.circle_points(c, 1.0, 8)
    @test length(pts) == 9  # n+1 points for closed circle
    # First and last should be same
    @test pts[1].x ≈ pts[end].x atol=1e-10
    @test pts[1].y ≈ pts[end].y atol=1e-10
  end

  @testset "Arc points generation" begin
    c = xyz(0, 0, 0)
    pts = KhepriMakie.arc_points(c, 1.0, 0, π/2, 16)
    @test length(pts) >= 2
    # First point at angle 0
    @test pts[1].x ≈ 1.0 atol=1e-10
    @test pts[1].y ≈ 0.0 atol=1e-10
  end

  # Conformance tests
  @testset "Backend Conformance (Makie)" begin
    include(joinpath(dirname(pathof(KhepriBase)), "..", "test", "BackendConformanceTests.jl"))
    using .BackendConformanceTests

    run_conformance_tests(makie,
      reset! = () -> begin
        empty!(makie.refs)
        makie.figure = nothing
        makie.axis = nothing
        makie.next_id = 1
        makie.scene_dirty = false
        makie.layer_names = Dict(1 => "default")
        makie.current_layer_id = 1
        makie.next_layer_id = 2
        backend(makie)
      end,
      skip = Symbol[]
    )
  end

end
