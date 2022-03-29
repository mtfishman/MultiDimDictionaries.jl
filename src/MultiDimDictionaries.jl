module MultiDimDictionaries
  using Reexport
  @reexport using Dictionaries

  export CartesianKey, LinearIndex

  import Base: keys, getindex, get, isassigned, setindex!, insert!, delete!, length, show, Tuple, eltype, ==, similar, vcat, hcat, hvncat
  import Dictionaries: issettable, isinsertable, gettokenvalue, merge

  include("linearindex.jl")
  include("cartesiankey.jl")

  # TODO: write in terms of `CartesianKey` instead of `Tuple`.
  # TODO: define a `LinearKey` which indexes into the internal data.
  # TODO: implement slicing with a `to_keys` generalization of `to_indices`.
  struct MultiDimDictionary{I<:CartesianKey,T,N,F<:Tuple} <: AbstractDictionary{I,T}
    dictionary::Dictionary{I,T}
    cat_map::F
    function MultiDimDictionary{I,T}(dictionary::Dictionary, cat_map::Tuple) where {I<:CartesianKey,T}
      #@assert length(I) == length(cat_map)
      return new{I,T,length(I),typeof(cat_map)}(dictionary, cat_map)
    end
  end

  function MultiDimDictionary{I,T}(dictionary::Dictionary) where {I<:CartesianKey,T}
    # XXX: This should be:
    #
    # N = length(I)
    # 
    # But sometimes the keys are of different lengths.
    N = length(first(keys(dictionary)))
    return MultiDimDictionary{I,T}(dictionary, ntuple(_ -> identity, Val(N)))
  end
  MultiDimDictionary{I}(dictionary::Dictionary{<:Any,T}) where {I,T} = MultiDimDictionary{I,T}(dictionary)

  MultiDimDictionary(dictionary::Dictionary{I,T}) where {I,T} = MultiDimDictionary{I,T}(dictionary)
  MultiDimDictionary{I,T}() where {I,T} = MultiDimDictionary{I,T}(Dictionary{I,T}())

  MultiDimDictionary(indexable) = MultiDimDictionary(Dictionary(indexable))
  MultiDimDictionary{I}(indexable) where {I} = MultiDimDictionary{I}(Dictionary(indexable))
  MultiDimDictionary{I,T}(indexable) where {I,T} = MultiDimDictionary{I,T}(Dictionary(indexable))

  MultiDimDictionary(inds, values) = MultiDimDictionary(Dictionary(inds, values))
  MultiDimDictionary{I}(inds, values) where {I} = MultiDimDictionary{I}(Dictionary(inds, values))
  MultiDimDictionary{I,T}(inds, values) where {I,T} = MultiDimDictionary{I,T}(Dictionary(inds, values))

  multidimdictionary(iter) = MultiDimDictionary(dictionary(iter))

  struct Add
    x::Int
  end
  (a::Add)(y::Int) = (a.x + y)
  (a::Add)(y) = y

  # High level sparse-array like constructors
  function MultiDimDictionary{I,T}(dims::NTuple{N,Int}) where {I,T,N}
    return MultiDimDictionary{I,T}(Dictionary{I,T}(), map(x -> Add(x), dims))
  end

  function MultiDimDictionary(::Type{T}, dims::NTuple{N,Int}) where {T,N}
    return MultiDimDictionary{CartesianKey{N,NTuple{N,Int}},T}(dims)
  end

  keys(dictionary::MultiDimDictionary) = keys(dictionary.dictionary)

  gettokenvalue(dictionary::MultiDimDictionary, token) = gettokenvalue(dictionary.dictionary, token)

  function getindex(dictionary::MultiDimDictionary{I,T}, index::I)::T where {I,T}
    return getindex(dictionary.dictionary, index)
  end

  function getindex(dictionary::MultiDimDictionary{I,T}, i...)::T where {I,T}
    return getindex(dictionary.dictionary, CartesianKey(i...))
  end

  function getindex(dictionary::MultiDimDictionary{I,T}, index::LinearIndex)::T where {I,T}
    return getindex(dictionary.dictionary.values, index.I)
  end

  isassigned(dictionary::MultiDimDictionary{I}, i::I) where {I} = isassigned(dictionary.dictionary, i)

  issetable(dictionary::MultiDimDictionary) = issetable(dictionary.dictionary)

  function _setindex!(dictionary::MultiDimDictionary, value, index)
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

  function merge(dictionary1::MultiDimDictionary{I1,T1}, dictionary2::MultiDimDictionary{I2,T2}) where {I1,T1,I2,T2}
    I = promote_type(I1, I2)
    T = promote_type(T1, T2)
    # TODO: Use `promote(dictionary1, dictionary2)` instead.
    return merge(MultiDimDictionary{I,T}(dictionary1), MultiDimDictionary{I,T}(dictionary2))
  end

  function merge(dictionary1::MultiDimDictionary{I,T}, dictionary2::MultiDimDictionary{I,T}) where {I,T}
    return MultiDimDictionary(merge(dictionary1.dictionary, dictionary2.dictionary))
  end

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
  function _shift_key(key::CartesianKey, fs::Tuple, dim::Int, dim_key=1)
    if dim > length(key)
      return CartesianKey(ntuple(j -> j == dim ? dim_key : (j > length(key) ? 1 : key[j]), dim)...)
    end
    return CartesianKey(ntuple(j -> j == dim ? fs[dim](key[dim]) : key[j], length(key))...)
  end

  function hvncat(dim::Int, dictionary1::MultiDimDictionary, dictionary2::MultiDimDictionary; dim_keys=(1, 2))
    shifted_keys = map(key -> _shift_key(key, dictionary1.cat_map, dim, dim_keys[2]), keys(dictionary2))
    # map doesn't narrow the types properly, so narrow them by hand
    narrowed_keytype = mapreduce(typeof, promote_type, shifted_keys)
    shifted_dictionary2 = MultiDimDictionary{narrowed_keytype}(shifted_keys, values(dictionary2))
    return merge(dictionary1, shifted_dictionary2)
  end

  vcat(dictionary1::MultiDimDictionary, dictionary2::MultiDimDictionary; dim_keys=(1, 2)) = hvncat(1, dictionary1, dictionary2; dim_keys=dim_keys)

  hcat(dictionary1::MultiDimDictionary, dictionary2::MultiDimDictionary; dim_keys=(1, 2)) = hvncat(2, dictionary1, dictionary2; dim_keys=dim_keys)

  #
  # exports
  #

  export MultiDimDictionary

end
