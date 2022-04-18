using MultiDimDictionaries
using Test

@testset "MultiDimDictionaries.jl" begin
  d = MultiDimDictionary(([(1, 1), (2, 1), (1, 2)]), [1, 2, 3])

  # Get elements

  @test d[1, 1] == 1
  @test d[2, 1] == 2
  @test d[1, 2] == 3

  @test d[(1, 1)] == 1
  @test d[(2, 1)] == 2
  @test d[(1, 2)] == 3

  @test d[LinearIndex(1)] == 1
  @test d[LinearIndex(2)] == 2
  @test d[LinearIndex(3)] == 3

  # Error
  # @test d[(1, 1)] == 1
  # @test d[(2, 1)] == 2
  # @test d[(1, 2)] == 3

  # Set elements

  d[1, 1] = 4
  d[(2, 1)] = 5
  d[LinearIndex(3)] = 6

  @test d[1, 1] == 4
  @test d[2, 1] == 5
  @test d[1, 2] == 6

  insert!(d, (2, 2), 12)

  @test d[2, 2] == 12

  delete!(d, (1, 1))

  @test !haskey(d, (1, 1))
  @test haskey(d, (1, 2))
  @test haskey(d, (2, 1))
  @test haskey(d, (2, 2))

  delete!(d, 1, 2)

  @test !haskey(d, 1, 1)
  @test !haskey(d, 1, 2)
  @test haskey(d, 2, 1)
  @test haskey(d, 2, 2)

  d2 = MultiDimDictionary([(3, 2), (2, 3)], [32, 23])
  d12 = merge(d, d2)

  @test d12 isa MultiDimDictionary
  @test !haskey(d12, 1, 2)
  @test haskey(d12, 2, 1)
  @test haskey(d12, 3, 2)

  d1 = MultiDimDictionary()
  d1[1] = 1
  d1[2] = 2

  @test d1[1] == 1
  @test d1[2] == 2

  d2 = MultiDimDictionary()
  d2[1] = 3
  d2[2] = 4

  @test d2[1] == 3
  @test d2[2] == 4

  dv = [d1; d2]

  @test dv[1] == 1
  @test dv[2] == 2
  @test dv[3] == 3
  @test dv[4] == 4

  dh = hcat(d1, d2)

  @test dh[1, 1] == 1
  @test dh[2, 1] == 2
  @test dh[1, 2] == 3
  @test dh[2, 2] == 4

  dh = hcat(d1, d2; new_dim_keys=("X", "Y"))

  @test dh[1, "X"] == 1
  @test dh[2, "X"] == 2
  @test dh[1, "Y"] == 3
  @test dh[2, "Y"] == 4

  dh_X = dh[:, "X"]

  @test dh_X[1, "X"] == 1
  @test dh_X[2, "X"] == 2
  @test !isassigned(dh_X, 1, "Y")
  @test !isassigned(dh_X, 2, "Y")

  dh_Y = dh[:, "Y"]

  @test dh_Y[1, "Y"] == 3
  @test dh_Y[2, "Y"] == 4

  dh_Z = dh[:, "Z"]

  @test !isassigned(dh_Z, 1, "X")
  @test !isassigned(dh_Z, 2, "X")
  @test !isassigned(dh_Z, 1, "Y")
  @test !isassigned(dh_Z, 2, "Y")

  d = d1 ⊔ d2

  @test d[1, 1] == 1
  @test d[1, 2] == 2
  @test d[2, 1] == 3
  @test d[2, 2] == 4

  d = disjoint_union(d1, d2; new_dim_keys=("X", "Y"))

  @test d["X", 1] == 1
  @test d["X", 2] == 2
  @test d["Y", 1] == 3
  @test d["Y", 2] == 4

  d_slice = d[[("X", 1), ("Y", 2)]]

  @test d_slice["X", 1] == 1
  @test !isassigned(d_slice, "X", 2)
  @test !isassigned(d_slice, "Y", 1)
  @test d_slice["Y", 2] == 4

  d2 = (d ⊔ d)[1, :]

  @test d2[1, "X", 1] == 1
  @test d2[1, "X", 2] == 2
  @test d2[1, "Y", 1] == 3
  @test d2[1, "Y", 2] == 4
end
