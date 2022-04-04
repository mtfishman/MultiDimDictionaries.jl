# MultiDimDictionaries

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://mtfishman.github.io/MultiDimDictionaries.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://mtfishman.github.io/MultiDimDictionaries.jl/dev)
[![Build Status](https://github.com/mtfishman/MultiDimDictionaries.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/mtfishman/MultiDimDictionaries.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/mtfishman/MultiDimDictionaries.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/mtfishman/MultiDimDictionaries.jl)
[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)

## TODO

- Define `hvncat(0, dictionary1, dictionary2)`, which takes keys like `CartesianKey("X", "Y")` to `CartesianKey(1, "X", "Y")` and `CartesianKey(2, "X", "Y")`, i.e. inserts new dimensions in the first position.
- Define `merge_dims(dictionary, [2, 3])` that takes keys like `CartesianKey(1, 2, 2)` to `CartesianKey(1, 4)` (based on strides determined from the dimensions). For non-integer keys, it can take `CartesianKey(1, "X", "Y")` to `CartesianKey(1, ("X", "Y"))`, i.e. put them into tuples.
