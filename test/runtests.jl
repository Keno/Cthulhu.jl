using Cthulhu
using Test

function process(@nospecialize(f), @nospecialize(TT); optimize=true)
    mi = Cthulhu.first_method_instance(f, TT)
    (ci, rt, slottypes) = Cthulhu.do_typeinf_slottypes(mi, optimize, Cthulhu.current_params())
    Cthulhu.preprocess_ci!(ci, mi, optimize)
    ci, mi, rt, slottypes
end

function find_callsites_by_ftt(@nospecialize(f), @nospecialize(TT); optimize=true)
    ci, mi, _, slottypes = process(f, TT; optimize=optimize)
    callsites = Cthulhu.find_callsites(ci, mi, slottypes)
end

# Testing that we don't have spurious calls from `Type`
callsites = find_callsites_by_ftt(Base.throw_boundserror, Tuple{UnitRange{Int64},Int64})
@test length(callsites) == 1

function test()
    T = rand() > 0.5 ? Int64 : Float64
    sum(rand(T, 100))
end

callsites = find_callsites_by_ftt(test, Tuple{})
@test length(callsites) == 3

callsites = find_callsites_by_ftt(test, Tuple{}; optimize=false)
@test length(callsites) == 2

if VERSION >= v"1.1.0-DEV.215" && Base.JLOptions().check_bounds == 0
Base.@propagate_inbounds function f(x)
    @boundscheck error()
end
g(x) = @inbounds f(x)
h(x) = f(x)

let CI, _, _, _ = process(g, Tuple{Vector{Float64}})
    @test length(CI.code) == 3
end

let CI, _, _, _ = process(h, Tuple{Vector{Float64}})
    @test length(CI.code) == 2
end
end
