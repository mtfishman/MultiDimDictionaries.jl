module MultiDimDictionaries
using Reexport
@reexport using Dictionaries

import Base:
  convert,
  copy,
  keys,
  getindex,
  get,
  isassigned,
  setindex!,
  insert!,
  delete!,
  length,
  show,
  Tuple,
  eltype,
  ==,
  similar,
  vcat,
  hcat,
  hvncat
import Dictionaries:
  deletetoken!,
  issettable,
  istokenizable,
  isinsertable,
  gettokenvalue,
  gettoken!,
  merge,
  haskey,
  settokenvalue!,
  set!

include("tuple_convert.jl")
include("linearindex.jl")

_isless(n1::Integer, n2::Integer) = (n1 < n2)
_isless(n1, n2) = false

function expand_dims!(dims, key)
  N = length(key)
  if length(dims) < N
    append!(dims, zeros(N - length(dims)))
  end
  @assert length(dims) ≥ N
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
struct MultiDimDictionary{I<:Tuple,T} <: AbstractDictionary{I,T}
  dictionary::Dictionary{I,T}
  dims::Vector{Int}
  function MultiDimDictionary{I,T}(
    ::Private, dictionary::Dictionary, dims::Vector{Int}
  ) where {I<:Tuple,T}
    # TODO: `dims` may be longer than `default_dims` if
    # a key was removed. Should `dims` be adjusted
    # when keys are removed?
    # @assert all(dims .≥ default_dims(dictionary))
    return new{I,T}(dictionary, dims)
  end
end

function copy(dictionary::MultiDimDictionary{I,T}) where {I,T}
  dictionary_copy = Dictionary(
    copy(dictionary.dictionary.indices), copy(dictionary.dictionary.values)
  )
  return MultiDimDictionary{I,T}(Private(), dictionary_copy, copy(dictionary.dims))
end

function MultiDimDictionary{I,T}(::Private, dictionary::Dictionary, dims) where {I<:Tuple,T}
  return MultiDimDictionary{I,T}(Private(), dictionary, collect(dims))
end

function MultiDimDictionary{I,T}(
  dictionary::Dictionary; dims=default_dims(dictionary)
) where {I<:Tuple,T}
  return MultiDimDictionary{I,T}(Private(), dictionary, dims)
end

function MultiDimDictionary{I}(dictionary::Dictionary; kwargs...) where {I<:Tuple}
  return MultiDimDictionary{I,eltype(dictionary)}(dictionary; kwargs...)
end

function MultiDimDictionary(dictionary::Dictionary{I,T}; kwargs...) where {I<:Tuple,T}
  return MultiDimDictionary{I,T}(dictionary; kwargs...)
end

function MultiDimDictionary(dictionary::Dictionary{I,T}; kwargs...) where {I,T}
  d = Dictionary{Tuple,T}(tuple_convert.(keys(dictionary)), dictionary)
  return MultiDimDictionary(d; kwargs...)
end

function MultiDimDictionary{I,T}(; kwargs...) where {I<:Tuple,T}
  return MultiDimDictionary{I,T}(Dictionary{I,T}(); kwargs...)
end

MultiDimDictionary(indexable) = MultiDimDictionary(Dictionary(indexable))

function MultiDimDictionary{I}(indexable) where {I<:Tuple}
  return MultiDimDictionary{I}(Dictionary(indexable))
end

function MultiDimDictionary{I,T}(indexable) where {I<:Tuple,T}
  return MultiDimDictionary{I,T}(Dictionary{I,T}(indexable))
end

MultiDimDictionary(inds, values) = MultiDimDictionary(Dictionary(inds, values))

function MultiDimDictionary{I}(inds, values) where {I<:Tuple}
  return MultiDimDictionary{I}(Dictionary{I}(inds, values))
end

function MultiDimDictionary{I,T}(inds, values) where {I<:Tuple,T}
  return MultiDimDictionary{I,T}(Dictionary{I,T}(inds, values))
end

MultiDimDictionary(; kwargs...) = MultiDimDictionary(Dictionary{Tuple}(); kwargs...)

multidimdictionary(iter) = MultiDimDictionary(dictionary(iter))

keys(dictionary::MultiDimDictionary) = keys(dictionary.dictionary)

function gettokenvalue(dictionary::MultiDimDictionary, token)
  return gettokenvalue(dictionary.dictionary, token)
end
function gettoken!(dictionary::MultiDimDictionary{I}, token::I) where {I}
  return gettoken!(dictionary.dictionary, token)
end

# Trait distinguishing if an index is a slice or just an element
abstract type IndexType end

struct SliceIndex <: IndexType end
struct ElementIndex <: IndexType end

# In general assume just an index
IndexType(::Any) = ElementIndex()

IndexType(::Colon) = SliceIndex()
IndexType(::Vector) = SliceIndex()
IndexType(::AbstractRange) = SliceIndex()

# For multi-index, check if any are SliceIndex
function IndexType(i1, i...)
  return any(x -> IndexType(x) isa SliceIndex, (i1, i...)) ? SliceIndex() : ElementIndex()
end

function getindex(dictionary::MultiDimDictionary, index::Tuple)
  return getindex(IndexType(index...), dictionary, index)
end

function getindex(dictionary::MultiDimDictionary, i...)
  return getindex(dictionary, tuple(i...))
end

function getindex(::ElementIndex, dictionary::MultiDimDictionary, index::Tuple)
  return getindex(dictionary.dictionary, index)
end

function getindex(::ElementIndex, dictionary::MultiDimDictionary, i...)
  return getindex(ElementIndex(), dictionary, tuple(i...))
end

function getindex(dictionary::MultiDimDictionary, index::LinearIndex)
  return getindex(dictionary.dictionary.values, index.I)
end

function isassigned(dictionary::MultiDimDictionary, index::Tuple)
  return isassigned(dictionary.dictionary, index)
end
isassigned(dictionary::MultiDimDictionary, i...) = isassigned(dictionary, (i...,))

haskey(dictionary::MultiDimDictionary, index::Tuple) = haskey(dictionary.dictionary, index)
haskey(dictionary::MultiDimDictionary, i...) = haskey(dictionary, (i...,))

issettable(dictionary::MultiDimDictionary) = issettable(dictionary.dictionary)

function setindex!(
  dictionary::MultiDimDictionary{I,T}, value::T, index::I
) where {I<:Tuple,T}
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

function set!(dictionary::MultiDimDictionary{I,T}, index::I, value::T) where {I<:Tuple,T}
  expand_dims!(dictionary.dims, index)
  set!(dictionary.dictionary, index, value)
  return dictionary
end

function set!(dictionary::MultiDimDictionary{I,T}, index::Tuple, value) where {I,T}
  return set!(dictionary, convert(I, index), convert(T, value))
end

function setindex!(dictionary::MultiDimDictionary, value, index::LinearIndex)
  # XXX: Expand dimensions
  setindex!(dictionary.dictionary.values, value, index.I)
  return dictionary
end

isinsertable(dictionary::MultiDimDictionary) = isinsertable(dictionary.dictionary)
istokenizable(dictionary::MultiDimDictionary) = istokenizable(dictionary.dictionary)
function settokenvalue!(dictionary::MultiDimDictionary{<:Any,T}, i, value::T) where {T}
  return settokenvalue!(dictionary.dictionary, i, value)
end

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

function deletetoken!(dictionary::MultiDimDictionary, index::Tuple)
  deletetoken!(dictionary.dictionary, index)
  return dictionary
end

function deletetoken!(dictionary::MultiDimDictionary, i...)
  return deletetoken!(dictionary, tuple(i...))
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

function index_in_slice(index::Tuple, index_slice::Tuple)
  if length(index) > length(index_slice)
    # This makes keys like `("X", 1, 2)` get
    # included in the indexing `dictionary["X", :]`.
    if !isa(last(index_slice), Colon)
      return false
    end
  elseif length(index) < length(index_slice)
    # This makes keys like `("X", 1)` get
    # included in the indexing `dictionary["X", 1, :]`.
    if any(x -> !isa(x, Colon), index_slice[(length(index) + 1):end])
      return false
    end
  end
  for dim in 1:min(length(index), length(index_slice))
    if !index_in_slice(index[dim], index_slice[dim])
      return false
    end
  end
  return true
end

# Drop singleton dimensions when slicing
function slice_index(index::Tuple, index_slice::Tuple)
  keep_dims = Int[]
  for dim in eachindex(index)
    if has_trailing_colon(dim, index_slice) || IndexType(index_slice[dim]) isa SliceIndex
      push!(keep_dims, dim)
    end
  end
  return index[keep_dims]
end

# Drop singleton dimensions when slicing
function slice_indices(
  ::SliceIndex, dictionary::MultiDimDictionary{I}, index_slice::Tuple
) where {I<:Tuple}
  sliced_indices = Indices{Tuple}()
  for index in keys(dictionary)
    if index_in_slice(index, index_slice)
      sliced_index = slice_index(index, index_slice)
      insert!(sliced_indices, sliced_index)
    end
  end
  return sliced_indices
end

function getindex_dropdims(
  ::SliceIndex, dictionary::MultiDimDictionary{I}, index_slice::Tuple
) where {I<:Tuple}
  indices = slice_indices_no_dropdims(SliceIndex(), dictionary, index_slice)
  sliced_indices = slice_indices(SliceIndex(), dictionary, index_slice)
  return MultiDimDictionary(sliced_indices, getindices(dictionary.dictionary, indices))
end

# Don't drop singleton dimensions when slicing
function slice_indices_no_dropdims(
  ::SliceIndex, dictionary::MultiDimDictionary{I}, index_slice::Tuple
) where {I<:Tuple}
  indices = Indices{I}()
  for index in keys(dictionary)
    if index_in_slice(index, index_slice)
      insert!(indices, index)
    end
  end
  return indices
end

function getindex(
  ::SliceIndex, dictionary::MultiDimDictionary{I}, index_slice::Tuple
) where {I<:Tuple}
  indices = slice_indices_no_dropdims(SliceIndex(), dictionary, index_slice)
  # Need convert because of:
  # https://github.com/andyferris/Dictionaries.jl/issues/97
  subdictionary = convert(
    typeof(dictionary.dictionary), getindices(dictionary.dictionary, indices)
  )
  return MultiDimDictionary(indices, subdictionary)
end

# Special version for `dictionary[[("X", 1), ("X", 2)]]`
function getindex(dictionary::MultiDimDictionary{I}, index::Vector) where {I<:Tuple}
  indices = Indices{I}()
  for key in keys(dictionary)
    if index_in_slice(key, index)
      insert!(indices, key)
    end
  end
  subdictionary = convert(
    typeof(dictionary.dictionary), getindices(dictionary.dictionary, indices)
  )
  return MultiDimDictionary(subdictionary)
end

function getindex(::SliceIndex, dictionary::MultiDimDictionary, indices...)
  return getindex(SliceIndex(), dictionary, tuple(indices...))
end

#
# Merging/disjoint unions
#

# Disjoint union without any relabelling (assumes the dictionaries already have
# unique keys).
function merge(
  dictionary1::MultiDimDictionary{I1,T1}, dictionary2::MultiDimDictionary{I2,T2}
) where {I1,T1,I2,T2}
  # TODO: Use `promote(dictionary1, dictionary2)` instead.
  I = promote_type(I1, I2)
  T = promote_type(T1, T2)
  return merge(MultiDimDictionary{I,T}(dictionary1), MultiDimDictionary{I,T}(dictionary2))
end

function merge(
  dictionary1::MultiDimDictionary{I,T}, dictionary2::MultiDimDictionary{I,T}
) where {I,T}
  d1 = dictionary1.dims
  d2 = dictionary2.dims
  dims = [max(get(d1, i, 0), get(d2, i, 0)) for i in 1:max(length(d1), length(d2))]
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
function hvncat(
  dim::Int,
  dictionary1::MultiDimDictionary,
  dictionary2::MultiDimDictionary;
  new_dim_keys=(1, 2),
)
  shifted_keys1 = map(
    key -> _shift_key(key, zero(dictionary1.dims), dim, new_dim_keys[1]), keys(dictionary1)
  )
  shifted_keys2 = map(
    key -> _shift_key(key, dictionary1.dims, dim, new_dim_keys[2]), keys(dictionary2)
  )

  ## # map doesn't narrow the types properly, so narrow them by hand
  ## narrowed_keytype1 = mapreduce(typeof, promote_type, shifted_keys1)
  ## narrowed_keytype2 = mapreduce(typeof, promote_type, shifted_keys2)

  narrowed_keytype1 = Tuple
  narrowed_keytype2 = Tuple

  shifted_dictionary1 = MultiDimDictionary{narrowed_keytype1}(
    shifted_keys1, values(dictionary1)
  )
  shifted_dictionary2 = MultiDimDictionary{narrowed_keytype2}(
    shifted_keys2, values(dictionary2)
  )
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
function disjoint_union(
  dictionary1::MultiDimDictionary, dictionary2::MultiDimDictionary; dim::Int=0, kwargs...
)
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
