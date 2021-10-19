###############################################################################
#
#   ExtPolyRing/sextpoly 
#
###############################################################################

const ExtPolyRingID = Dict{Tuple{Union{Ring, Field}, Array{Symbol, 1},
                                 libSingular.rRingOrder_t, libSingular.rRingOrder_t},
                           AbstractAlgebra.NCRing}()

mutable struct ExtPolyRing{T <: Nemo.RingElem} <: AbstractAlgebra.NCRing
   ptr::libSingular.ring_ptr
   refcount::Int
   base_ring::Union{Ring, Field}
   ord::Symbol
   S::Vector{Symbol}

   # take ownership of a ring_ptr
   function ExtPolyRing{T}(r::libSingular.ring_ptr, R, ord::Symbol,
                           s::Vector{Symbol}=singular_symbols(r)) where T <: Nemo.RingElem
      d = new(r, 1, R, ord, s)
      finalizer(_PolyRing_clear_fn, d)
      return d
   end
end

# TODO clean up this mess and support fancy orderings
function ExtPolyRing{T}(R::Union{Ring, Field}, s::Array{Symbol, 1},
                        ord_sym::Symbol, cached::Bool = true,
                        ordering::libSingular.rRingOrder_t = ringorder_dp,
                        ordering2::libSingular.rRingOrder_t = ringorder_C) where T

   length(s) >= 2 || error("need at least two indeterminates")

   # check ordering: accept exactly one of ringorder_c, ringorder_C
   if (((ordering == ringorder_c || ordering == ringorder_C)
            && (ordering2 == ringorder_c || ordering2 == ringorder_C))
         || ((ordering != ringorder_c && ordering != ringorder_C)
            && (ordering2 != ringorder_c && ordering2 != ringorder_C)))
      error("wrong ordering")
   end
   n_vars = Cint(length(s));
   if cached && haskey(ExtPolyRingID, (R, s, ordering, ordering2))
      return ExtPolyRingID[R, s, ordering, ordering2]::ExtPolyRing{T}
   else
      ss = rename_symbols(all_singular_symbols(R), String.(s), "x")
      v = [pointer(Base.Vector{UInt8}(string(str)*"\0")) for str in ss]
      r = libSingular.nCopyCoeff(R.ptr)

      blk0 = unsafe_wrap(Array, Ptr{Cint}(libSingular.omAlloc0(Csize_t(3*sizeof(Cint)))), 3; own=false)
      blk1 = unsafe_wrap(Array, Ptr{Cint}(libSingular.omAlloc0(Csize_t(3*sizeof(Cint)))), 3; own=false)
      if (ordering == ringorder_c || ordering == ringorder_C)
         blk0[1] = Cint(0)
         blk1[1] = Cint(0)
         blk0[2] = Cint(1)
         blk1[2] = Cint(length(v))
      else
         blk0[1] = Cint(1)
         blk1[1] = Cint(length(v))
         blk0[2] = Cint(0)
         blk1[2] = Cint(0)
      end
      ord = Array{libSingular.rRingOrder_t, 1}(undef, 3)
      ord[1] = ordering
      ord[2] = ordering2
      ord[3] = ringorder_no
      ptr = libSingular.rExterior(r, v, ord, blk0, blk1, Culong(0)) # TODO remove the useless degbound parameter
      z = ExtPolyRing{T}(ptr, R, ord_sym, s)
      ExtPolyRingID[R, s, ordering, ordering2] = z
      return z
   end
end

mutable struct sextpoly{T <: Nemo.RingElem} <: AbstractAlgebra.NCRingElem
   ptr::libSingular.poly_ptr
   parent::ExtPolyRing{T}

   function sextpoly{T}(R::ExtPolyRing{T}) where T <: Nemo.RingElem
      p = libSingular.p_ISet(0, R.ptr)
      z = new{T}(p, R)
      R.refcount += 1
      finalizer(_sextpoly_clear_fn, z)
      return z
   end
    
   function sextpoly{T}(R::ExtPolyRing{T}, p::libSingular.poly_ptr) where T <: Nemo.RingElem
      z = new{T}(p, R)
      R.refcount += 1
      finalizer(_sextpoly_clear_fn, z)
      return z
   end
    
   function sextpoly{T}(R::ExtPolyRing{T}, p::T) where T <: Nemo.RingElem
      n = libSingular.n_Copy(p.ptr, parent(p).ptr)
      r = libSingular.p_NSet(n, R.ptr)
      z = new{T}(r, R)
      R.refcount += 1
      finalizer(_sextpoly_clear_fn, z)
      return z
   end
    
   function sextpoly{T}(R::ExtPolyRing{T}, n::libSingular.number_ptr) where T <: Nemo.RingElem
      nn = libSingular.n_Copy(n, base_ring(R).ptr)
      p = libSingular.p_NSet(nn, R.ptr)
      z = new{T}(p, R)
      R.refcount += 1
      finalizer(_sextpoly_clear_fn, z)
      return z
   end

   function sextpoly{T}(R::ExtPolyRing{T}, n::Ptr{Cvoid}) where T <: Nemo.RingElem
      p = libSingular.p_NSet(n, R.ptr)
      z = new(p, R)
      R.refcount += 1
      finalizer(_sextpoly_clear_fn, z)
      return z
   end

   function sextpoly{T}(R::ExtPolyRing{T}, b::Int) where T <: Nemo.RingElem
      p = libSingular.p_ISet(b, R.ptr)
      z = new{T}(p, R)
      R.refcount += 1
      finalizer(_sextpoly_clear_fn, z)
      return z
   end

   function sextpoly{T}(R::ExtPolyRing{T}, b::BigInt) where T <: Nemo.RingElem
      n = libSingular.n_InitMPZ(b, R.base_ring.ptr)
      p = libSingular.p_NSet(n, R.ptr)
      z = new{T}(p, R)
      R.refcount += 1
      finalizer(_sextpoly_clear_fn, z)
      return z
   end
end

function _sextpoly_clear_fn(p::sextpoly)
   R = parent(p)
   libSingular.p_Delete(p.ptr, R.ptr)
   _PolyRing_clear_fn(R)
end

