__precompile__()
module BinaryFileVectors

export BitstypeFileVector, open_existing, create_empty, mmap_existing

using ArgCheck: @argcheck
using Parameters: @unpack
using DocStringExtensions: SIGNATURES
import Mmap: mmap, sync!

import Base: append!, eltype, length, push!, flush, close, isopen


# generic

abstract type BinaryFileVector{T} end

eltype(::BinaryFileVector{T}) where T = T


# header

const MAGIC = 0x31564642        # "BFV1"

function write_header(io::IO, ::Type{T}) where T
    write(io, MAGIC)
    write(io, Int32(sizeof(T)))
end

function verify_header(io::IO, ::Type{T}) where T
    @argcheck read(io, UInt32) == MAGIC
    @argcheck read(io, Int32) == sizeof(T)
    nothing
end

const HEADERLEN = 8

const WRITEERRMSG = "Failed while writing to disk; stream closed or disk full?"


#

mutable struct BitstypeFileVector{T} <: BinaryFileVector{T}
    io::IOStream
    len::Int
    function BitstypeFileVector{T}(io::IOStream, len::Int) where T
        @argcheck isbitstype(T)
        new{T}(io, len)
    end
end

length(b::BitstypeFileVector) = b.len

flush(b::BitstypeFileVector) = flush(b.io)

close(b::BitstypeFileVector) = close(b.io)

isopen(b::BitstypeFileVector) = isopen(b.io)

function push!(b::BitstypeFileVector{T}, x::T) where T
    @argcheck write(b.io, Ref(x)) == sizeof(T) ErrorException(WRITEERRMSG)
    b.len += 1
    b
end

push!(b::BitstypeFileVector{T}, x) where T = push!(b, convert(T, x))

function append!(b::BitstypeFileVector{T}, v::Vector{T}) where T
    @argcheck write(b.io, v) == sizeof(v) ErrorException(WRITEERRMSG)
    b.len += length(v)
    b
end

append!(b::BitstypeFileVector, itr) = (foreach(elt -> push!(b, elt), itr); b)

function mmap(b::BitstypeFileVector{T}) where T
    @unpack io, len = b
    flush(io)
    seek(io, HEADERLEN)
    mmap(io, Vector{T}, len)
end

function open_existing(::Type{BitstypeFileVector{T}}, datafile::AbstractString) where T
    @argcheck isfile(datafile) ErrorException("File $(datafile) not found.")
    totalsize = filesize(datafile)
    io = open(datafile, "a+")
    seekstart(io)
    verify_header(io, T)
    len, rem = divrem((totalsize - HEADERLEN), sizeof(T))
    @argcheck rem == 0 "$(rem) dangling bytes at the of the file."
    seekend(io)
    BitstypeFileVector{T}(io, len)
end

function mmap_existing(T::Type{<:BinaryFileVector}, path)
    b = open_existing(T, path)
    v = mmap(b)
    close(b)
    v
end

function create_empty(::Type{BitstypeFileVector{T}}, datafile::AbstractString;
                      overwrite = false) where T
    if !overwrite
        @argcheck !isfile(datafile) "Found existing file, use overwrite = true."
    end
    io = open(datafile, "w+")
    write_header(io, T)
    BitstypeFileVector{T}(io, 0)
end

end # module
