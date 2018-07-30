using BinaryFileVectors
using Test
using Mmap: mmap

@testset "collect and mmap" begin
    filename = tempname()
    T = Float64

    # create and fill
    b = create_empty(BitstypeFileVector{T}, filename)
    @test eltype(b) == T
    @test length(b) == 0
    @test push!(b, 1.0) ≡ b
    @test push!(b, 2) ≡ b
    @test append!(b, T[3.0, 4.0]) ≡ b
    @test append!(b, [5, 6]) ≡ b
    @test length(b) == 6

    # mmap
    m = mmap(b)
    @test m isa Vector{T}
    @test length(m) == 6
    @test m == Float64.(1:6)

    # won't overwrite existing file
    @test_throws ArgumentError create_empty(BitstypeFileVector{T}, filename)

    # open, add, then mmap
    b2 = open_existing(BitstypeFileVector{T}, filename)
    push!(b2, 7.0)
    m2 = mmap(b2)
    @test m2 isa Vector{T}
    @test length(m2) == 7
    @test m2 == Float64.(1:7)
end

@testset "consistency checks" begin
    # size mismatch
    fn = tempname()
    b = create_empty(BitstypeFileVector{Int32}, fn)
    flush(b)
    @test_throws ArgumentError open_existing(BitstypeFileVector{Int64}, fn)

    # bad magic
    fn = tempname()
    @test_throws ErrorException open_existing(BitstypeFileVector{Int64}, fn)
    open(fn * ".bin", "w") do io
        write(io, Int32(0))
    end
    @test_throws ArgumentError open_existing(BitstypeFileVector{Int64}, fn)

end
