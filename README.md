# PythonBufferInterface.jl

Defines a Julia analogue of the [Python buffer interface](https://docs.python.org/3/c-api/buffer.html).

By default this includes all strided arrays whose elements are of bits types.

You can test whether an object defines the interface, and query it for information such
as the size of the buffer and a pointer to the data.

## Install

```
pkg> add PythonBufferInterface
```

## Usage

Call `pybuf_info(x)` on any object. If it satisfies the buffer interface then a named tuple
of information is returned. Otherwise `nothing` is returned.

As a slightly lower level interface, you may call `b = pybuf_buffer(x)`. If `x` satisfies
the interface then `b` is not `nothing` and can be queried for information:
- `pybuf_ptr(b)`
- `pybuf_readonly(b)`
- `pybuf_itemsize(b)`
- `pybuf_format(b)`
- `pybuf_ndim(b)`
- `pybuf_shape(b, i)` / `pybuf_shape(b)`
- `pybuf_stride(b, i)` / `pybuf_strides(b)`
- `pybuf_suboffset(b, i)` / `pybuf_suboffsets(b)`
- `pybuf_len(b)`

The meaning of these is as defined in the [Python buffer interface](https://docs.python.org/3/c-api/buffer.html).

## Implementing the interface

Any strided array whose eltype is a bits type or a struct of bits types already implements
the interface.

If you wish to implement the interface for your type `T`, you must overload the following:
- `pybuf_buffer(x::T) -> b` or `nothing` if `x` is not a buffer; is is reasonable to simply return `x`
- `pybuf_ptr(b)::Ptr{Cvoid}` (default: `Ptr{Cvoid}(Base.unsafe_convert(Ptr{eltype(b)}, b))`)
- `pybuf_readonly(b)::Bool` (default: `!ArrayInterface.can_setindex(typeof(b))`)
- `pybuf_itemsize(b)::Int` (default: `Int(sizeof(eltype(b)))`)
- `pybuf_format(b)::String` (default: `pybuf_format(eltype(b))`)
- `pybuf_ndim(b)::Int` (default: `Int(ndims(b))`)
- `pybuf_shape(b, i)::Int` (default: `Int(size(b, i))`)
- `pybuf_stride(b, i)::Int` (default: `Int(stride(b, i) * Base.aligned_sizeof(eltype(b)))`)
- `pybuf_suboffset(b, i)::Int` (default: `-1`)
