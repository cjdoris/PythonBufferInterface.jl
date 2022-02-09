module PythonBufferInterface

import ArrayInterface

export pybuf_info, pybuf_buffer, pybuf_ptr, pybuf_readonly, pybuf_itemsize, pybuf_format, pybuf_ndim, pybuf_shape, pybuf_stride, pybuf_strides, pybuf_suboffset, pybuf_suboffsets, pybuf_len

const TYPE_TO_TYPESTR = Dict(
    Cchar => "b",
    Cuchar => "B",
    Cshort => "h",
    Cushort => "H",
    Cint => "i",
    Cuint => "I",
    Clong => "l",
    Culong => "L",
    Clonglong => "q",
    Culonglong => "Q",
    Float16 => "e",
    Cfloat => "f",
    Cdouble => "d",
    Complex{Float16} => "Ze",
    Complex{Cfloat} => "Zf",
    Complex{Cdouble} => "Zd",
    Bool => "?",
    Ptr{Cvoid} => "P",
)

### Interface

"""
    pybuf_buffer(x)

If `x` does not satisfy the Python buffer interface, return `nothing`. Otherwise return an
object `b` which can be queried for information using functions such as `pybuf_ptr`,
`pybuf_ndim`, etc.
"""
pybuf_buffer(x) = nothing
pybuf_buffer(x::AbstractArray) = is_pybuf_eltype(eltype(x)) && ArrayInterface.defines_strides(typeof(x)) && ArrayInterface.device(typeof(x)) == ArrayInterface.CPUPointer() ? x : nothing

"""
    pybuf_ptr(b)

Pointer to the start of the data in buffer `b`.
"""
pybuf_ptr(b) = Ptr{Cvoid}(Base.unsafe_convert(Ptr{eltype(b)}, b))

"""
    pybuf_readonly(b)

True if the buffer `b` is read only.
"""
pybuf_readonly(b) = !ArrayInterface.can_setindex(typeof(b))

"""
    pybuf_itemsize(b)

The size in bytes of a single item in the buffer `b`.
"""
pybuf_itemsize(b) = Int(sizeof(eltype(b)))

"""
    pybuf_format(b)

The format string describing an element of the buffer `b`.
"""
pybuf_format(b) = pybuf_format(eltype(b))

"""
    pybuf_ndim(b)

The number of dimensions in buffer `b`.
"""
pybuf_ndim(b) = Int(ndims(b))

"""
    pybuf_shape(b, i)

The size of the buffer `b` along dimension `i`.
"""
pybuf_shape(b, i) = Int(size(b, i))

"""
    pybuf_stride(b, i)

The distance in bytes between consecutive elements of buffer `b` along dimension `i`.
"""
pybuf_stride(b, i) = Int(stride(b, i) * Base.aligned_sizeof(eltype(b)))

"""
    pybuf_suboffset(b, i)

The suboffsets in buffer `b` along dimension `i`.
"""
pybuf_suboffset(b, i) = -1


### Utils

"""
    is_pybuf_eltype(T::Type)

Return true if items of type `T` are compatible with the buffer interface.

That is, `T` must be a bits type or a struct of these.
"""
@generated is_pybuf_eltype(::Type{T}) where {T} = (
    isconcretetype(T) &&
    Base.allocatedinline(T) &&
    isa(T, DataType) &&
    (
        isbitstype(T) ||
        (
            isstructtype(T) &&
            all(i->is_pybuf_eltype(fieldtype(T, i)), 1:fieldcount(T))
        )
    )
)

"""
    pybuf_format(T::Type)

The format string describing items of type `T`.
"""
@generated pybuf_format(::Type{T}) where {T} =
    if !is_pybuf_eltype(T)
        error("invalid Python buffer element type")
    elseif haskey(TYPE_TO_TYPESTR, T)
        TYPE_TO_TYPESTR[T]
    elseif isstructtype(T)
        n = fieldcount(T)
        flds = []
        for i = 1:n
            nm = fieldname(T, i)
            tp = fieldtype(T, i)
            push!(flds, string(pybuf_format(tp), nm isa Symbol ? ":$nm:" : ""))
            off0 = fieldoffset(T, i) + sizeof(tp)
            off1 = i == n ? sizeof(T) : fieldoffset(T, i + 1)
            d = off1 - off0
            @assert d ≥ 0
            d > 0 && push!(flds, "$(d)x")
        end
        string("T{", join(flds, " "), "}")
    elseif isbitstype(T)
        "$(sizeof(T))x"
    else
        @assert false
    end

"""
    pybuf_shape(b)

The size of the buffer `b` along each dimension.
"""
pybuf_shape(b) = ntuple(i->pybuf_shape(b, i)::Int, pybuf_ndim(b)::Int)

"""
    pybuf_strides(b)

The distance in bytes between consecutive elements of buffer `b` along each dimension.
"""
pybuf_strides(b) = ntuple(i->pybuf_stride(b, i)::Int, pybuf_ndim(b)::Int)

"""
    pybuf_suboffsets(b)

The suboffsets in buffer `b` along each dimension.
"""
pybuf_suboffsets(b) = ntuple(i->pybuf_suboffset(b, i)::Int, pybuf_ndim(b)::Int)

"""
    pybuf_len(b)

The size of the buffer `b` in bytes if it were stored contiguously.
"""
pybuf_len(b) = (prod(pybuf_shape(b)) * pybuf_itemsize(b))::Int

"""
    pybuf_info(x)

If `x` satisfies the buffer protocol, return a named tuple describing it. Otherwise return
`nothing`.

The named tuple has fields `buffer`, `ptr`, `len`, `readonly`, `itemsize`, `format`,
`ndim`, `shape`, `strides`, `suboffsets` corresponding to the outputs of the `pybuf_*`
functions.

The information in the tuple remains valid as long as the `buffer` is not GC'd.
"""
pybuf_info(x) = if (b = pybuf_buffer(x)) !== nothing
    (
        buffer = b,
        ptr = pybuf_ptr(b)::Ptr{Cvoid},
        len = pybuf_len(b)::Int,
        readonly = pybuf_readonly(b)::Bool,
        itemsize = pybuf_itemsize(b)::Int,
        format = pybuf_format(b)::String,
        ndim = pybuf_ndim(b)::Int,
        shape = pybuf_shape(b)::Tuple{Vararg{Int}},
        strides = pybuf_strides(b)::Tuple{Vararg{Int}},
        suboffsets = pybuf_suboffsets(b)::Tuple{Vararg{Int}},
    )
end

end # module
