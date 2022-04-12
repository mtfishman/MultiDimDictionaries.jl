# Tuple constructor that either keeps
# it as a Tuple or turns it into a Tuple.
tuple_convert(t::Tuple) = t
tuple_convert(x) = tuple(x)
