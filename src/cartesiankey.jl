struct CartesianKey{N,T<:Tuple}
  I::T
  function CartesianKey{N,T}(index...) where {N,T}
    @assert length(index) == N
    return new{N,T}((index...,))
  end
end
CartesianKey{N}(index...) where {N} = CartesianKey{N,typeof(index)}(index...)
CartesianKey(index...) = CartesianKey{length(index)}(index...)

CartesianKey(key::CartesianKey) = key
CartesianKey{N}(key::CartesianKey{N}) where {N} = key
CartesianKey{N,T}(key::CartesianKey{N,T}) where {N,T} = key

show(io::IO, i::CartesianKey) = (print(io, "CartesianKey"); show(io, i.I))

# length
length(::CartesianKey{N}) where {N} = N
length(::Type{<:CartesianKey{N}}) where {N} = N
length(::Type{CartesianKey}) = Any

# indexing
getindex(index::CartesianKey, i::Integer) = index.I[i]
get(A::AbstractArray, I::CartesianKey, default) = get(A, I.I, default)
eltype(::Type{T}) where {T<:CartesianKey} = eltype(fieldtype(T, :I))

# access to index tuple
Tuple(index::CartesianKey) = index.I

Base.setindex(x::CartesianKey,i,j) = CartesianKey(Base.setindex(Tuple(x),i,j))

# equality
(a::CartesianKey{N} == b::CartesianKey{N}) where {N} = a.I == b.I

## Optional code taken from CartesianIndex defition in Base Julia
## # Allow passing tuples smaller than N
## CartesianIndex{N}(index::Tuple) where {N} = CartesianIndex{N}(fill_to_length(index, 1, Val(N)))
## CartesianIndex{N}(index::Integer...) where {N} = CartesianIndex{N}(index)
## CartesianIndex{N}() where {N} = CartesianIndex{N}(())

## # Un-nest passed CartesianIndexes
## CartesianIndex(index::Union{Integer, CartesianIndex}...) = CartesianIndex(flatten(index))
## flatten(I::Tuple{}) = I
## flatten(I::Tuple{Any}) = I
## flatten(I::Tuple{<:CartesianIndex}) = I[1].I
## @inline flatten(I) = _flatten(I...)
## @inline _flatten() = ()
## @inline _flatten(i, I...)                 = (i, _flatten(I...)...)
## @inline _flatten(i::CartesianIndex, I...) = (i.I..., _flatten(I...)...)
## CartesianIndex(index::Tuple{Vararg{Union{Integer, CartesianIndex}}}) = CartesianIndex(index...)
