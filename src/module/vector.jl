###############################################################################
#
#   Basic manipulation
#
###############################################################################

parent{T <: Nemo.RingElem}(v::svector{T}) = FreeMod{T}(v.base_ring, v.rank)

base_ring(R::FreeMod) = R.base_ring

base_ring(v::svector) = v.base_ring

elem_type{T <: Nemo.RingElem}(::FreeMod{T}) = T

parent_type{T <: Nemo.RingElem}(v::svector{T}) = FreeMod{T}

rank(R::FreeMod) = R.rank

function deepcopy(p::svector)
   p2 = libSingular.p_Copy(p.ptr, parent(p).ptr)
   return Singular.Vector(p.base_ring, p.rank, p2)
end

function check_parent{T <: Nemo.RingElem}(a::svector{T}, b::svector{T})
   base_ring(a) != base_ring(b) && error("Incompatible base rings")
   a.rank != b.rank && error("Vectors of incompatible rank")
end

function check_parent{T <: Nemo.RingElem}(a::svector{spoly{T}}, b::spoly{T})
   base_ring(a) != parent(b) && error("Incompatible base rings")
end

###############################################################################
#
#   String I/O
#
###############################################################################

function show(io::IO, R::FreeMod)
   print(io, "Free Module of rank ", R.rank, " over ")
   show(io, R.base_ring)
end

function show(io::IO, a::svector)
   m = libSingular.p_String(a.ptr, base_ring(a).ptr)
   s = unsafe_string(m)
   libSingular.omFree(Ptr{Void}(m))
   print(io, s)
end


###############################################################################
#
#   Unary functions
#
###############################################################################

function -(a::svector)
   R = base_ring(a)
   a1 = libSingular.p_Copy(a.ptr, R.ptr)
   s = libSingular.p_Neg(a1, R.ptr)
   return Singular.Vector(R, a.rank, s) 
end

###############################################################################
#
#   Arithmetic functions
#
###############################################################################

function +{T <: Nemo.RingElem}(a::svector{T}, b::svector{T})
   check_parent(a, b)
   R = base_ring(a)
   a1 = libSingular.p_Copy(a.ptr, R.ptr)
   b1 = libSingular.p_Copy(b.ptr, R.ptr)
   s = libSingular.p_Add_q(a1, b1, R.ptr)
   return Singular.Vector(R, a.rank, s) 
end

function -{T <: Nemo.RingElem}(a::svector{T}, b::svector{T})
   check_parent(a, b)
   R = base_ring(a)
   a1 = libSingular.p_Copy(a.ptr, R.ptr)
   b1 = libSingular.p_Copy(b.ptr, R.ptr)
   s = libSingular.p_Sub(a1, b1, R.ptr)
   return Singular.Vector(R, a.rank, s) 
end

###############################################################################
#
#   Ad hoc arithmetic functions
#
###############################################################################

function *{T <: Nemo.RingElem}(a::svector{spoly{T}}, b::spoly{T})
   check_parent(a, b)
   R = base_ring(a)
   a1 = libSingular.p_Copy(a.ptr, R.ptr)
   b1 = libSingular.p_Copy(b.ptr, R.ptr)
   s = libSingular.p_Mult_q(a1, b1, R.ptr)
   return Singular.Vector(R, a.rank, s)
end

*{T <: Nemo.RingElem}(a::spoly{T}, b::svector{spoly{T}}) = b*a

*{T <: Nemo.RingElem}(a::svector{spoly{T}}, b::T) = a*base_ring(a)(b)

*{T <: Nemo.RingElem}(a::T, b::svector{spoly{T}}) = b*a

*(a::svector, b::Integer) = a*base_ring(a)(b)

*(a::Integer, b::svector) = b*a

###############################################################################
#
#   Comparison
#
###############################################################################

function =={T <: Nemo.RingElem}(x::svector{T}, y::svector{T})
    check_parent(x, y)
    return Bool(libSingular.p_EqualPolys(x.ptr, y.ptr, base_ring(x).ptr))
end

###############################################################################
#
#   Vector Constructors
#
###############################################################################

function Vector{T <: Nemo.RingElem}(R::PolyRing{T}, r::Int, p::libSingular.poly)
   return svector{T}(R, r, p)
end

function Array{T <: Nemo.RingElem}(v::svector{T})
   n = v.rank
   a=Array{spoly, 1}(n)
   aa=Array{libSingular.poly, 1}(n)
   R=v.base_ring
   libSingular.p_Vector2Array(v.ptr, aa, n, R.ptr)
   for i in 1:n
     a[i]=spoly{T}(R, aa[i])
   end
   return a
end

function svector{T <: Nemo.RingElem}(a::Array{spoly{T}, 1})
  n = size(a)[1]
  aa=Array{libSingular.poly, 1}(n)
  for i in 1:n
    aa[i]=a[i].ptr
  end
  v=libSingular.id_Array2Vector(aa,n,parent(a[1]).ptr)
  return svector{T}(parent(a[1]), n, v)
end
