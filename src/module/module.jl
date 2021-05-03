export jet, minimal_generating_set, ModuleClass, rank, smodule, slimgb, eliminate, modulo, lift

###############################################################################
#
#   Basic manipulation
#
###############################################################################

parent(a::smodule{T}) where T <: Nemo.RingElem = ModuleClass{T}(a.base_ring)

base_ring(S::ModuleClass) = S.base_ring

base_ring(I::smodule) = I.base_ring

elem_type(::ModuleClass{T}) where T <: AbstractAlgebra.RingElem = smodule{T}

elem_type(::Type{ModuleClass{T}}) where T <: AbstractAlgebra.RingElem = smodule{T}

parent_type(::Type{smodule{T}}) where T <: AbstractAlgebra.RingElem = ModuleClass{T}


@doc Markdown.doc"""
    ngens(I::smodule)

Return the number of generators in the current representation of the module (as a list
of vectors).
"""
ngens(I::smodule) = I.ptr == C_NULL ? 0 : Int(libSingular.ngens(I.ptr))

@doc Markdown.doc"""
    rank(I::smodule)

Return the rank $n$ of the ambient space $R^n$ of which this module is a submodule.
"""
rank(I::smodule) = Int(GC.@preserve I libSingular.rank(I.ptr))

function checkbounds(I::smodule, i::Int)
   (i > ngens(I) || i < 1) && throw(BoundsError(I, i))
end

function getindex(I::smodule{T}, i::Int) where T <: AbstractAlgebra.RingElem
   checkbounds(I, i)
   R = base_ring(I)
   GC.@preserve I R begin
      p = libSingular.getindex(I.ptr, Cint(i - 1))
      return svector{T}(R, rank(I), libSingular.p_Copy(p, R.ptr))
   end
end

@doc Markdown.doc"""
    iszero(p::smodule)

Return `true` if this is algebraically the zero module.
"""
iszero(p::smodule) = Bool(libSingular.idIs0(p.ptr))

function deepcopy_internal(I::smodule, dict::IdDict)
   R = base_ring(I)
   ptr = GC.@preserve I R libSingular.id_Copy(I.ptr, R.ptr)
   return Module(R, ptr)
end

function check_parent(I::smodule{T}, J::smodule{T}) where T <: Nemo.RingElem
   base_ring(I) != base_ring(J) && error("Incompatible modules")
end

function hash(M::smodule, h::UInt)
   v = 0x403fd5a7748e75c9%UInt
   for i in 1:ngens(M)
      v = xor(hash(M[i], h), v)
   end
   return v
end

###############################################################################
#
#   String I/O
#
###############################################################################

function show(io::IO, S::ModuleClass)
   print(io, "Class of Singular Modules over ")
   show(io, base_ring(S))
end

function show(io::IO, I::smodule)
   print(io, "Singular Module over ")
   show(io, base_ring(I))
   println(io,", with Generators:")
   n = ngens(I)
   for i = 1:n
      show(io, I[i])
      if i != n
         println(io, "")
      end
   end
end

###############################################################################
#
#   Groebner basis
#
###############################################################################

@doc Markdown.doc"""
    std(I::smodule; complete_reduction::Bool=false)

Compute the Groebner basis of the module $I$. If `complete_reduction` is
set to `true`, the result is unique, up to permutation of the generators
and multiplication by constants. If not, only the leading terms are unique
(up to permutation of the generators and multiplication by constants, of
course). Presently the polynomial ring used must be over a field or over
the Singular integers.
"""
function std(I::smodule; complete_reduction::Bool=false)
   R = base_ring(I)
   ptr = GC.@preserve I R libSingular.id_Std(I.ptr, R.ptr, complete_reduction)
   libSingular.idSkipZeroes(ptr)
   z = Module(R, ptr)
   z.isGB = true
   return z
end

@doc Markdown.doc"""
    slimgb(I::smodule; complete_reduction::Bool=false)

Given a module $I$ this function computes a Groebner basis for it.
Compared to `std`, `slimgb` uses different strategies for choosing
a reducer.
>
If the optional parameter `complete_reduction` is set to `true` the
function computes a reduced Gröbner basis for $I$.
"""
function slimgb(I::smodule; complete_reduction::Bool=false)
   R = base_ring(I)
   ptr = GC.@preserve I R libSingular.id_Slimgb(I.ptr, R.ptr, complete_reduction)
   libSingular.idSkipZeroes(ptr)
   z = Module(R, ptr)
   z.isGB = true
   return z
end

###############################################################################
#
#   Reduction
#
###############################################################################

@doc Markdown.doc"""
   reduce(M::smodule, G::smodule)
Return a submodule whose generators are the generators of $M$ reduced by the
submodule $G$. The submodule $G$ is required to be given by a Groebner basis. The returned
submodule will have the same number of generators as $M$, even if they are zero.
"""
function reduce(M::smodule, G::smodule)
   check_parent(M, G)
   R = base_ring(M)
   !G.isGB && error("Not a Groebner basis")
   ptr = GC.@preserve M G R libSingular.p_Reduce(M.ptr, G.ptr, R.ptr)
   return Module(R, ptr)
end

###############################################################################
#
#   Syzygies
#
###############################################################################

@doc Markdown.doc"""
    syz(M::smodule)

Compute the module of syzygies of the given module. This will be given as
a set of generators in an ambient space $R^n$, where $n$ is the number of
generators in $M$.
"""
function syz(M::smodule)
   R = base_ring(M)
   ptr = GC.@preserve M R libSingular.id_Syzygies(M.ptr, R.ptr)
   libSingular.idSkipZeroes(ptr)
   return Module(R, ptr)
end

###############################################################################
#
#   Resolutions
#
###############################################################################

@doc Markdown.doc"""
    sres{T <: Nemo.RingElem}(I::smodule{T}, max_length::Int)

Compute a free resolution of the given module $I$ of length up to the given
maximum length. If `max_length` is set to zero, a full length free
resolution is computed. Each element of the resolution is itself a module.
"""
function sres(I::smodule{T}, max_length::Int) where T <: Nemo.RingElem
   I.isGB == false && error("Not a Groebner basis ideal")
   R = base_ring(I)
   if max_length == 0
        max_length = nvars(R)
        # TODO: consider qrings
   end
   r, minimal = GC.@preserve I R libSingular.id_sres(I.ptr, Cint(max_length + 1), R.ptr)
   return sresolution{T}(R, r, Bool(minimal))
end

###############################################################################
#
#   Module constructors
#
###############################################################################

function Module(R::PolyRing{T}, vecs::svector{spoly{T}}...) where T <: Nemo.RingElem
   S = elem_type(R)
   return smodule{S}(R, vecs...)
end

function Module(R::PolyRing{T}, id::libSingular.ideal_ptr) where T <: Nemo.RingElem
   S = elem_type(R)
   return smodule{S}(R, id)
end

###############################################################################
#
#   Differential functions
#
###############################################################################

@doc Markdown.doc"""
   jet(M::smodule, n::Int)
Given a module $M$ this function truncates the generators of $M$
up to degree $n$.
"""
function jet(M::smodule, n::Int)
      R = base_ring(M)
      ptr = GC.@preserve M R libSingular.id_Jet(M.ptr, Cint(n), R.ptr)
      libSingular.idSkipZeroes(ptr)
      return Module(R, ptr)
end

###############################################################################
#
#   Functions for local rings
#
###############################################################################

@doc Markdown.doc"""
   minimal_generating_set(M::smodule)
Given a module $M$ in ring $R$ with local ordering, this returns an array
containing the minimal generators of $M$.
"""
function minimal_generating_set(M::smodule)
   R = base_ring(M)
   if has_global_ordering(R) || has_mixed_ordering(R)
      error("Ring needs local ordering.")
   end
   N = GC.@preserve M R Singular.Module(R, Singular.libSingular.idMinBase(M.ptr, R.ptr))
   return [N[i] for i in 1:ngens(N)]
end


###############################################################################
#
#   Eliminate
#
###############################################################################

@doc Markdown.doc"""
    eliminate(M::smodule, polys::spoly...)

Given a list of polynomials which are variables, construct the
the intersection of M with the free module
where those variables have been eliminated.
"""
function eliminate(M::smodule, polys::spoly...)
   R = base_ring(M)
   p = one(R)
   for i = 1:length(polys)
      !isgen(polys[i]) && error("Not a variable")
      parent(polys[i]) != R && error("Incompatible base rings")
      p *= polys[i]
   end
   ptr = GC.@preserve M p R libSingular.id_Eliminate(M.ptr, p.ptr, R.ptr)
   return Module(R, ptr)
end

###############################################################################
#
#   Lift
#
###############################################################################

@doc Markdown.doc"""
    lift(M::smodule, SM::smodule)

represents the generators of SM in terms of the generators of M.
Returns result, rest
(Matrix(SM) = (Matrix(M)-Matrix(rest))*matrix(result))
If SM is in M, rest is the null module
"""
function lift(M::smodule, SM::smodule)
   R = base_ring(M)
   ptr,rest_ptr = GC.@preserve M SM R libSingular.id_Lift(M.ptr, SM.ptr, R.ptr)
   return Module(R, ptr),Module(R,rest_ptr)
end

###############################################################################
#
#   LiftStd
#
###############################################################################

@doc Markdown.doc"""
    lift_std_syz(M::smodule)

computes the Groebner base G of M, the transformation matrix T and the syzygies of M.
Returns G,T,S
(Matrix(G) = Matrix(M) * T, 0=Matrix(M)*Matrix(S))
"""
function lift_std_syz(M::smodule; complete_reduction::Bool = false)
   R = base_ring(M)
   ptr,T_ptr,S_ptr = GC.@preserve M R libSingular.id_LiftStdSyz(M.ptr, R.ptr, complete_reduction)
   return Module(R, ptr), smatrix{elem_type(R)}(R, T_ptr), Module(R,S_ptr)
end

@doc Markdown.doc"""
    lift_std(M::smodule)

computes the Groebner base G of M and the transformation matrix T such that
(Matrix(G) = Matrix(M) * T)
"""
function lift_std(M::smodule; complete_reduction::Bool = false)
   R = base_ring(M)
   ptr,T_ptr = GC.@preserve M R libSingular.id_LiftStd(M.ptr, R.ptr, complete_reduction)
   return Module(R, ptr), smatrix{elem_type(R)}(R, T_ptr)
end

###############################################################################
#
#   Modulo
#
###############################################################################

@doc Markdown.doc"""
    modulo(A::smodule, B:smodule)

represents  A/(A intersect B) (isomorphic to (A+B)/B)
"""
function modulo(A::smodule, B::smodule)
   R = base_ring(A)
   ptr = GC.@preserve A B R libSingular.id_Modulo(A.ptr, B.ptr, R.ptr)
   return Module(R, ptr)
end

