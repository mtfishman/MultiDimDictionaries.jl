mutable struct MutableNTuple{N,T}
  data::NTuple{N,T}
  function MutableNTuple(data::NTuple{N,T}) where {N,T}
    @assert isbitstype(T)
    return new{N,T}(data)
  end
end

Base.@propagate_inbounds function Base.getindex(t::MutableNTuple{N,T}, i::Int) where {N,T}
  @boundscheck checkbounds(Base.OneTo(N),i)
  GC.@preserve t unsafe_load(Base.unsafe_convert(Ptr{T}, pointer_from_objref(t)), i)
end

Base.@propagate_inbounds function Base.setindex!(t::MutableNTuple{N,T}, val, i::Int) where {N,T}
  @boundscheck checkbounds(Base.OneTo(N),i)
  GC.@preserve t unsafe_store!(Base.unsafe_convert(Ptr{T}, pointer_from_objref(t)), convert(T, val), i)
  return t
end

@inline Base.Tuple(t::MutableNTuple) = t.data

Base.length(t::MutableNTuple{N}) where {N} = N

Base.:+(t1::MutableNTuple, t2::MutableNTuple) = MutableNTuple(t1.data .+ t2.data)
