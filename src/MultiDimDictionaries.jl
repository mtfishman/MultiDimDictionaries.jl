module MultiDimDictionaries
  using Reexport
  @reexport using Dictionaries

  export CartesianKey, LinearIndex

  import Base: keys, getindex, get, isassigned, setindex!, insert!, delete!, length, show, Tuple, eltype, ==, similar, vcat, hcat, hvncat
  import Dictionaries: issettable, isinsertable, gettokenvalue, merge

  include("linearindex.jl")
  include("cartesiankey.jl")

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

  # TODO: implement slicing with a `to_keys` generalization of `to_indices`.
  struct MultiDimDictionary{I<:CartesianKey,T,N} <: AbstractDictionary{I,T}
    dictionary::Dictionary{I,T}
    dims::Vector{Int}
    function MultiDimDictionary{I,T}(dictionary::Dictionary, dims::Vector{Int}) where {I,T}
      N = max_key_length(dictionary)
      @assert N == length(dims)
      return new{I,T,N}(dictionary, dims)
    end
  end

  # Automatically determine the dimensions
  function MultiDimDictionary{I,T}(dictionary::Dictionary) where {I<:CartesianKey,T}
    return MultiDimDictionary{I,T}(dictionary, default_dims(dictionary))
  end

  function MultiDimDictionary{I}(dictionary::Dictionary{<:Any,T}) where {I,T}
    return MultiDimDictionary{I,T}(dictionary)
  end

  function MultiDimDictionary{I}(dictionary::Dictionary{<:Any,T}, dims) where {I,T}
    return MultiDimDictionary{I,T}(dictionary, dims)
  end

  function MultiDimDictionary(dictionary::Dictionary{I,T}, dims) where {I,T}
    return MultiDimDictionary{I,T}(dictionary, dims)
  end

  function MultiDimDictionary(dictionary::Dictionary{I,T}) where {I,T}
    return MultiDimDictionary{I,T}(dictionary)
  end
  MultiDimDictionary{I,T}() where {I,T} = MultiDimDictionary{I,T}(Dictionary{I,T}())

  MultiDimDictionary(indexable) = MultiDimDictionary(Dictionary(indexable))
  MultiDimDictionary{I}(indexable) where {I} = MultiDimDictionary{I}(Dictionary(indexable))
  MultiDimDictionary{I,T}(indexable) where {I,T} = MultiDimDictionary{I,T}(Dictionary(indexable))

  MultiDimDictionary(inds, values) = MultiDimDictionary(Dictionary(inds, values))
  MultiDimDictionary{I}(inds, values) where {I} = MultiDimDictionary{I}(Dictionary(inds, values))
  MultiDimDictionary{I,T}(inds, values) where {I,T} = MultiDimDictionary{I,T}(Dictionary(inds, values))

  MultiDimDictionary() = MultiDimDictionary(Dictionary{CartesianKey}())

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

  function getindex(dictionary::MultiDimDictionary{I,T}, index::I)::T where {I,T}
    return getindex(dictionary.dictionary, index)
  end

  function getindex(::ElementIndex, dictionary::MultiDimDictionary{I,T}, i...)::T where {I,T}
    return getindex(dictionary.dictionary, CartesianKey(i...))
  end

  function getindex(dictionary::MultiDimDictionary{I,T}, i...)::T where {I,T}
    return getindex(index_type(i...), dictionary, i...)
  end

  function getindex(dictionary::MultiDimDictionary{I,T}, index::LinearIndex)::T where {I,T}
    return getindex(dictionary.dictionary.values, index.I)
  end

  isassigned(dictionary::MultiDimDictionary{I}, i::I) where {I<:CartesianKey} = isassigned(dictionary.dictionary, i)
  isassigned(dictionary::MultiDimDictionary, i...) = isassigned(dictionary, CartesianKey(i...))

  issetable(dictionary::MultiDimDictionary) = issetable(dictionary.dictionary)

  function _setindex!(dictionary::MultiDimDictionary, value, index)
    expand_dims!(dictionary.dims, index)
    set!(dictionary.dictionary, index, value)
    return dictionary
  end

  function setindex!(dictionary::MultiDimDictionary{I,T}, value::T, index::I) where {I,T}
    return _setindex!(dictionary, value, index)
    return dictionary
  end

  function setindex!(dictionary::MultiDimDictionary{I,T}, value, index::I) where {I,T}
    return _setindex!(dictionary, value, index)
  end

  function setindex!(dictionary::MultiDimDictionary{I,T}, value::T, i...) where {I,T}
    return _setindex!(dictionary, value, CartesianKey(i...))
  end

  function setindex!(dictionary::MultiDimDictionary{I,T}, value, i...) where {I,T}
    return _setindex!(dictionary, value, CartesianKey(i...))
  end

  function setindex!(dictionary::MultiDimDictionary{I,T}, value::T, index::LinearIndex) where {I,T}
    setindex!(dictionary.dictionary.values, value, index.I)
    return dictionary
  end

  isinsertable(dictionary::MultiDimDictionary) = isinsertable(dictionary.dictionary)

  function insert!(dictionary::MultiDimDictionary{I,T}, index::I, value::T) where {I,T}
    insert!(dictionary.dictionary, index, value)
    return dictionary
  end

  function delete!(dictionary::MultiDimDictionary{I,T}, index::I) where {I,T}
    delete!(dictionary.dictionary, index)
    return dictionary
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

  function index_in_slice(index::CartesianKey, slice::Tuple)
    for n in 1:length(index)
      !index_in_slice(index[n], slice[n]) && return false
    end
    return true
  end

  function getindex(::SliceIndex, dictionary::MultiDimDictionary{I,T}, i...)::T where {I,T}
    indices = Indices{I}()
    for key in keys(dictionary)
      if index_in_slice(key, (i...,))
        insert!(indices, key)
      end
    end
    return MultiDimDictionary(getindices(dictionary.dictionary, indices))
  end

  #
  # Concatenation
  #

  function merge(dictionary1::MultiDimDictionary{I1,T1}, dictionary2::MultiDimDictionary{I2,T2}) where {I1,T1,I2,T2}
    # TODO: Use `promote(dictionary1, dictionary2)` instead.
    I = promote_type(I1, I2)
    T = promote_type(T1, T2)
    return merge(MultiDimDictionary{I,T}(dictionary1), MultiDimDictionary{I,T}(dictionary2))
  end

  function merge(dictionary1::MultiDimDictionary{I,T}, dictionary2::MultiDimDictionary{I,T}) where {I,T}
    dims = max.(dictionary1.dims, dictionary2.dims)
    return MultiDimDictionary(merge(dictionary1.dictionary, dictionary2.dictionary), dims)
  end

  _add(n1::Integer, n2::Integer) = n1 + n2
  _add(n1, n2::Integer) = n2
  _add(n1::Integer, n2) = n1

  # Either shift the key in dimension `dim` by `fs[dim]`, or if
  # `dim > length(key)` then extend the key to length `dim` by padding
  # with 1s and insert `dim_key` at dimension `dim`.
  #
  # For example:
  #
  # f = x -> x + 3
  #
  # _shift_key(CartesianKey(2, 2, 2), (f, f, f), 2) -> CartesianKey(2, 5, 2)
  #
  # _shift_key(CartesianKey(2, 2, 2), (f, f, f), 3) -> CartesianKey(2, 2, 5)
  #
  # _shift_key(CartesianKey(2, 2, 2), (f, f, f), 4) -> CartesianKey(2, 2, 2, 1)
  #
  # _shift_key(CartesianKey(2, 2, 2), (f, f, f), 4, "X") -> CartesianKey(2, 2, 2, "X")
  function _shift_key(key::CartesianKey, dims, dim::Int, dim_key=1)
    if dim > length(key)
      return CartesianKey(ntuple(j -> j == dim ? dim_key : (j > length(key) ? 1 : key[j]), dim)...)
    end
    return CartesianKey(ntuple(j -> j == dim ? _add(dims[dim], key[dim]) : key[j], length(key))...)
  end

  function hvncat(dim::Int, dictionary1::MultiDimDictionary, dictionary2::MultiDimDictionary; new_dim_keys=(1, 2))
    shifted_keys1 = map(key -> _shift_key(key, zero(dictionary1.dims), dim, new_dim_keys[1]), keys(dictionary1))
    shifted_keys2 = map(key -> _shift_key(key, dictionary1.dims, dim, new_dim_keys[2]), keys(dictionary2))

    ## # map doesn't narrow the types properly, so narrow them by hand
    ## narrowed_keytype1 = mapreduce(typeof, promote_type, shifted_keys1)
    ## narrowed_keytype2 = mapreduce(typeof, promote_type, shifted_keys2)

    narrowed_keytype1 = CartesianKey
    narrowed_keytype2 = CartesianKey

    shifted_dictionary1 = MultiDimDictionary{narrowed_keytype1}(shifted_keys1, values(dictionary1))
    shifted_dictionary2 = MultiDimDictionary{narrowed_keytype2}(shifted_keys2, values(dictionary2))
    return merge(shifted_dictionary1, shifted_dictionary2)
  end

  function vcat(dictionary1::MultiDimDictionary, dictionary2::MultiDimDictionary; new_dim_keys=(1, 2))
    return hvncat(1, dictionary1, dictionary2; new_dim_keys=new_dim_keys)
  end

  function hcat(dictionary1::MultiDimDictionary, dictionary2::MultiDimDictionary; new_dim_keys=(1, 2))
    return hvncat(2, dictionary1, dictionary2; new_dim_keys=new_dim_keys)
  end

  #
  # exports
  #

  export MultiDimDictionary

end
