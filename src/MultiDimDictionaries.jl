module MultiDimDictionaries
  using Reexport
  @reexport using Dictionaries

  import Base: convert, keys, getindex, get, isassigned, setindex!, insert!, delete!, length, show, Tuple, eltype, ==, similar, vcat, hcat, hvncat
  import Dictionaries: issettable, isinsertable, gettokenvalue, merge, haskey

  include("linearindex.jl")

  _isless(n1::Integer, n2::Integer) = (n1 < n2)
  _isless(n1, n2) = false

  function expand_dims!(dims, key)
    N = length(key)
    if length(dims) < N
      append!(dims, zeros(N - length(dims)))
    end
    @assert length(dims) == N
    for n in 1:N
      if _isless(dims[n], key[n])
        dims[n] = key[n]
      end
    end
    return dims
  end

  max_key_length(dictionary::Dictionary) = maximum(length.(keys(dictionary)); init=0)

  function default_dims(dictionary::Dictionary)
    isempty(dictionary) && return Int[]
    N = max_key_length(dictionary)
    # Determine the dimensions automatically from the keys
    dims = fill(0, N)
    for key in keys(dictionary)
      expand_dims!(dims, key)
    end
    return dims
  end

  struct Private end

  # TODO: implement slicing with a `to_keys` generalization of `to_indices`.
  struct MultiDimDictionary{I<:Tuple,T,N} <: AbstractDictionary{I,T}
    dictionary::Dictionary{I,T}
    dims::Vector{Int}
    function MultiDimDictionary{I,T}(::Private, dictionary::Dictionary, dims::Vector{Int}) where {I<:Tuple,T}
      N = max_key_length(dictionary)
      @assert N == length(dims)
      return new{I,T,N}(dictionary, dims)
    end
  end

  function MultiDimDictionary{I,T}(dictionary::Dictionary; dims=default_dims(dictionary)) where {I<:Tuple,T}
    return MultiDimDictionary{I,T}(Private(), dictionary, dims)
  end

  function MultiDimDictionary{I}(dictionary::Dictionary; kwargs...) where {I}
    return MultiDimDictionary{I,eltype(dictionary)}(dictionary; kwargs...)
  end

  function MultiDimDictionary(dictionary::Dictionary{I,T}; kwargs...) where {I,T}
    return MultiDimDictionary{I,T}(dictionary; kwargs...)
  end

  MultiDimDictionary{I,T}(; kwargs...) where {I,T} = MultiDimDictionary{I,T}(Dictionary{I,T}(); kwargs...)

  MultiDimDictionary(indexable) = MultiDimDictionary(Dictionary(indexable))
  MultiDimDictionary{I}(indexable) where {I} = MultiDimDictionary{I}(Dictionary(indexable))
  MultiDimDictionary{I,T}(indexable) where {I,T} = MultiDimDictionary{I,T}(Dictionary(indexable))

  MultiDimDictionary(inds, values) = MultiDimDictionary(Dictionary(inds, values))
  MultiDimDictionary{I}(inds, values) where {I} = MultiDimDictionary{I}(Dictionary(inds, values))
  MultiDimDictionary{I,T}(inds, values) where {I,T} = MultiDimDictionary{I,T}(Dictionary(inds, values))

  MultiDimDictionary() = MultiDimDictionary(Dictionary{Tuple}())

  multidimdictionary(iter) = MultiDimDictionary(dictionary(iter))

  keys(dictionary::MultiDimDictionary) = keys(dictionary.dictionary)

  gettokenvalue(dictionary::MultiDimDictionary, token) = gettokenvalue(dictionary.dictionary, token)

  # Trait distinguishing if an index is a slice or just an element
  struct SliceIndex end
  struct ElementIndex end

  # In general assume just an index
  index_type(::Any) = ElementIndex()

  index_type(::Colon) = SliceIndex()
  index_type(::Vector) = SliceIndex()
  index_type(::AbstractRange) = SliceIndex()

  # For multi-index, check if any are SliceIndex
  index_type(i1, i...) = any(x -> index_type(x) isa SliceIndex, (i1, i...)) ? SliceIndex() : ElementIndex()

  function getindex(dictionary::MultiDimDictionary, index::Tuple)
    return getindex(index_type(index...), dictionary, index)
  end

  function getindex(dictionary::MultiDimDictionary, i...)
    return getindex(dictionary, tuple(i...))
  end

  function getindex(::ElementIndex, dictionary::MultiDimDictionary, index::Tuple)
    return getindex(dictionary.dictionary, index)
  end

  function getindex(index_type::ElementIndex, dictionary::MultiDimDictionary, i...)
    return getindex(index_type, dictionary, tuple(i...))
  end

  function getindex(dictionary::MultiDimDictionary, index::LinearIndex)
    return getindex(dictionary.dictionary.values, index.I)
  end

  isassigned(dictionary::MultiDimDictionary, index::Tuple) = isassigned(dictionary.dictionary, index)
  isassigned(dictionary::MultiDimDictionary, i...) = isassigned(dictionary, (i...,))

  haskey(dictionary::MultiDimDictionary, index::Tuple) = haskey(dictionary.dictionary, index)
  haskey(dictionary::MultiDimDictionary, i...) = haskey(dictionary, (i...,))

  issetable(dictionary::MultiDimDictionary) = issetable(dictionary.dictionary)

  function setindex!(dictionary::MultiDimDictionary{I,T}, value::T, index::I) where {I<:Tuple,T}
    expand_dims!(dictionary.dims, index)
    set!(dictionary.dictionary, index, value)
    return dictionary
  end

  function setindex!(dictionary::MultiDimDictionary{I,T}, value, index::Tuple) where {I,T}
    return setindex!(dictionary, convert(T, value), convert(I, index))
  end

  function setindex!(dictionary::MultiDimDictionary, value, i...)
    return setindex!(dictionary, value, tuple(i...))
  end

  function setindex!(dictionary::MultiDimDictionary, value, index::LinearIndex)
    setindex!(dictionary.dictionary.values, value, index.I)
    return dictionary
  end

  isinsertable(dictionary::MultiDimDictionary) = isinsertable(dictionary.dictionary)

  function insert!(dictionary::MultiDimDictionary{I,T}, index::I, value::T) where {I<:Tuple,T}
    insert!(dictionary.dictionary, index, value)
    return dictionary
  end

  function insert!(dictionary::MultiDimDictionary{I,T}, index::Tuple, value) where {I,T}
    return insert!(dictionary, convert(I, index), convert(T, value))
  end

  function delete!(dictionary::MultiDimDictionary, index::Tuple)
    delete!(dictionary.dictionary, index)
    return dictionary
  end

  function delete!(dictionary::MultiDimDictionary, i...)
    return delete!(dictionary, tuple(i...))
  end

  #
  # Slicing
  #

  index_in_slice(index, slice::Colon) = true
  index_in_slice(index, slice::AbstractRange) = (index ∈ slice)
  index_in_slice(index, slice::Vector) = (index ∈ slice)

  function index_in_slice(index, slice)
    return index == slice
  end

  function index_in_slice(index::Tuple, slice::Tuple)
    for n in 1:length(index)
      !index_in_slice(index[n], slice[n]) && return false
    end
    return true
  end

  function getindex(::SliceIndex, dictionary::MultiDimDictionary{I}, index::Tuple) where {I<:Tuple}
    indices = Indices{I}()
    for key in keys(dictionary)
      if index_in_slice(key, index)
        insert!(indices, key)
      end
    end
    return MultiDimDictionary(getindices(dictionary.dictionary, indices))
  end

  function getindex(index_type::SliceIndex, dictionary::MultiDimDictionary, indices...)
    return getindex(index_type, dictionary, tuple(indices...))
  end

  #
  # Merging/disjoint unions
  #

  # Disjoint union without any relabelling (assumes the dictionaries already have
  # unique keys).
  function merge(dictionary1::MultiDimDictionary{I1,T1}, dictionary2::MultiDimDictionary{I2,T2}) where {I1,T1,I2,T2}
    # TODO: Use `promote(dictionary1, dictionary2)` instead.
    I = promote_type(I1, I2)
    T = promote_type(T1, T2)
    return merge(MultiDimDictionary{I,T}(dictionary1), MultiDimDictionary{I,T}(dictionary2))
  end

  function merge(dictionary1::MultiDimDictionary{I,T}, dictionary2::MultiDimDictionary{I,T}) where {I,T}
    dims = max.(dictionary1.dims, dictionary2.dims)
    return MultiDimDictionary(merge(dictionary1.dictionary, dictionary2.dictionary); dims)
  end

  _add(n1::Integer, n2::Integer) = n1 + n2
  _add(n1, n2::Integer) = n2
  _add(n1::Integer, n2) = n1

  """
      _shift_key(key::Tuple, dims::Tuple, dim::Int, dim_key=1)
  
  Either shift the key in dimension `dim` by `dims[d]`, or if
  `dim > length(key)` then extend the key to length `dim` by padding
  with 1s and insert `dim_key` at dimension `dim`.
  
  For example:
  
  f = x -> x + 3
  
  _shift_key(Tuple(2, 2, 2), [3, 3, 3], 2) -> Tuple(2, 5, 2)
  
  _shift_key(Tuple(2, 2, 2), [3, 3, 3], 3) -> Tuple(2, 2, 5)
  
  _shift_key(Tuple(2, 2, 2), [3, 3, 3], 4) -> Tuple(2, 2, 2, 1)
  
  _shift_key(Tuple(2, 2, 2), [3, 3, 3], 4, "X") -> Tuple(2, 2, 2, "X")
  
  _shift_key(Tuple(2, 2, 2), [3, 3, 3], 0) -> Tuple(1, 2, 5, 2)

  _shift_key(Tuple(2, 2, 2), [3, 3, 3], 0, "X") -> Tuple("X", 2, 5, 2)

  This is an "injection": https://en.wikipedia.org/wiki/Disjoint_union
  """
  function _shift_key(key::Tuple, dims::Vector{Int}, dim::Int, dim_key=1)
    if dim < 0
      error("Not implemented dim=$dim")
    elseif dim == 0
      return (dim_key, key...)
    elseif dim > length(key)
      return ntuple(j -> j == dim ? dim_key : (j > length(key) ? 1 : key[j]), dim)
    end
    return ntuple(j -> j == dim ? _add(dims[dim], key[dim]) : key[j], length(key))
  end

  # This is a "disjoint union": https://en.wikipedia.org/wiki/Disjoint_union
  # "⊔" can be typed by \sqcup<tab>
  function hvncat(dim::Int, dictionary1::MultiDimDictionary, dictionary2::MultiDimDictionary; new_dim_keys=(1, 2))
    shifted_keys1 = map(key -> _shift_key(key, zero(dictionary1.dims), dim, new_dim_keys[1]), keys(dictionary1))
    shifted_keys2 = map(key -> _shift_key(key, dictionary1.dims, dim, new_dim_keys[2]), keys(dictionary2))

    ## # map doesn't narrow the types properly, so narrow them by hand
    ## narrowed_keytype1 = mapreduce(typeof, promote_type, shifted_keys1)
    ## narrowed_keytype2 = mapreduce(typeof, promote_type, shifted_keys2)

    narrowed_keytype1 = Tuple
    narrowed_keytype2 = Tuple

    shifted_dictionary1 = MultiDimDictionary{narrowed_keytype1}(shifted_keys1, values(dictionary1))
    shifted_dictionary2 = MultiDimDictionary{narrowed_keytype2}(shifted_keys2, values(dictionary2))
    return merge(shifted_dictionary1, shifted_dictionary2)
  end

  function vcat(dictionary1::MultiDimDictionary, dictionary2::MultiDimDictionary; kwargs...)
    return hvncat(1, dictionary1, dictionary2; kwargs...)
  end

  function hcat(dictionary1::MultiDimDictionary, dictionary2::MultiDimDictionary; kwargs...)
    return hvncat(2, dictionary1, dictionary2; kwargs...)
  end

  # TODO: define `disjoint_union(dictionaries...; dim::Int, new_dim_keys)` to do a disjoint union
  # of a number of dictionaries.
  function disjoint_union(dictionary1::MultiDimDictionary, dictionary2::MultiDimDictionary; dim::Int=0, kwargs...)
    return hvncat(dim, dictionary1, dictionary2; kwargs...)
  end

  function ⊔(dictionary1::MultiDimDictionary, dictionary2::MultiDimDictionary; kwargs...)
    return disjoint_union(dictionary1, dictionary2; kwargs...)
  end

  #
  # exports
  #

  export MultiDimDictionary, LinearIndex, disjoint_union, ⊔

end
