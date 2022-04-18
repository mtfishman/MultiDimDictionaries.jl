using MultiDimDictionaries

d = MultiDimDictionary(([(1, 1), (2, 1), (1, 2)]), [1, 2, 3])

# Get elements

@show d[1, 1] == 1
@show d[2, 1] == 2
@show d[1, 2] == 3

@show d[(1, 1)] == 1
@show d[(2, 1)] == 2
@show d[(1, 2)] == 3

@show d[LinearIndex(1)] == 1
@show d[LinearIndex(2)] == 2
@show d[LinearIndex(3)] == 3

# Error
# @show d[(1, 1)] == 1
# @show d[(2, 1)] == 2
# @show d[(1, 2)] == 3

# Set elements

@show d[1, 1] = 4
@show d[(2, 1)] = 5
@show d[LinearIndex(3)] = 6

@show d[1, 1] == 4
@show d[2, 1] == 5
@show d[1, 2] == 6

insert!(d, (2, 2), 12)

@show d[2, 2] == 12

delete!(d, (1, 1))

@show !haskey(d, (1, 1))
@show haskey(d, (1, 2))
@show haskey(d, (2, 1))
@show haskey(d, (2, 2))

delete!(d, 1, 2)

@show !haskey(d, 1, 1)
@show !haskey(d, 1, 2)
@show haskey(d, 2, 1)
@show haskey(d, 2, 2)

d2 = MultiDimDictionary([(3, 2), (2, 3)], [32, 23])
d12 = merge(d, d2)

@show d12 isa MultiDimDictionary
@show !haskey(d12, 1, 2)
@show haskey(d12, 2, 1)
@show haskey(d12, 3, 2)

d1 = MultiDimDictionary()
d1[1] = 1
d1[2] = 2

@show d1[1] == 1
@show d1[2] == 2

d2 = MultiDimDictionary()
d2[1] = 3
d2[2] = 4

@show d2[1] == 3
@show d2[2] == 4

dv = [d1; d2]

@show dv[1] == 1
@show dv[2] == 2
@show dv[3] == 3
@show dv[4] == 4

dh = hcat(d1, d2)

@show dh[1, 1] == 1
@show dh[2, 1] == 2
@show dh[1, 2] == 3
@show dh[2, 2] == 4

dh = hcat(d1, d2; new_dim_keys=("X", "Y"))

@show dh[1, "X"] == 1
@show dh[2, "X"] == 2
@show dh[1, "Y"] == 3
@show dh[2, "Y"] == 4

dh_X = dh[:, "X"]

@show dh_X[1, "X"] == 1
@show dh_X[2, "X"] == 2
@show !isassigned(dh_X, 1, "X")
@show !isassigned(dh_X, 2, "X")

dh_Y = dh[:, "Y"]

@show dh_Y[1, "Y"] == 3
@show dh_Y[2, "Y"] == 4

dh_Z = dh[:, "Z"]

@show !isassigned(dh_Z, 1, "X")
@show !isassigned(dh_Z, 2, "X")
@show !isassigned(dh_Z, 1, "Y")
@show !isassigned(dh_Z, 2, "Y")

d = d1 ⊔ d2

@show d[1, 1] == 1
@show d[1, 2] == 2
@show d[2, 1] == 3
@show d[2, 2] == 4

d = disjoint_union(d1, d2; new_dim_keys=("X", "Y"))

@show d["X", 1] == 1
@show d["X", 2] == 2
@show d["Y", 1] == 3
@show d["Y", 2] == 4

d_slice = d[[("X", 1), ("Y", 2)]]

@show d_slice["X", 1] == 1
@show !isassigned(d_slice, "X", 2)
@show !isassigned(d_slice, "Y", 1)
@show d_slice["Y", 2] == 4

d2 = (d ⊔ d)[1, :]

@show d2[1, "X", 1] == 1
@show d2[1, "X", 2] == 2
@show d2[1, "Y", 1] == 3
@show d2[1, "Y", 2] == 4
