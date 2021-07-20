export sideal, IdealSet, syz, lead, normalize!, isconstant, iszerodim, fglm,
       fres, dimension, highcorner, jet, kbase, minimal_generating_set,
       independent_sets, maximal_independent_set, ngens, sres, intersection,
       quotient, reduce, eliminate, kernel, equal, contains, isvar_generated,
       saturation, satstd, slimgb, std, vdim

###############################################################################
#
#   Basic manipulation
#
###############################################################################

parent(a::sideal{T}) where {T <: Nemo.RingElem} = IdealSet{T}(a.base_ring)

base_ring(S::IdealSet) = S.base_ring

base_ring(I::sideal) = I.base_ring

elem_type(::Type{IdealSet{spoly{T}}}) where T <: Nemo.RingElem = sideal{spoly{T}}

elem_type(::IdealSet{spoly{T}}) where T <: Nemo.RingElem = sideal{spoly{T}}

parent_type(::Type{sideal{spoly{T}}}) where T <: Nemo.RingElem = IdealSet{spoly{T}}

@doc Markdown.doc"""
    ngens(I::sideal)

Return the number of generators in the internal representation of the ideal $I$.
"""
function ngens(I::sideal)
   GC.@preserve I return Int(libSingular.ngens(I.ptr))
end

@doc Markdown.doc"""
    gens(I::sideal)

Return the generators in the internal representation of the ideal $I$ as an array.
"""
function gens(I::sideal)
   R = base_ring(I)
   ngens(I) == 0 && return Array{elem_type(R), 1}()
   return [I[i] for i in 1:Singular.ngens(I)]
end

function checkbounds(I::sideal, i::Int)
   (i > ngens(I) || i < 1) && throw(BoundsError(I, i))
end

function setindex!(I::sideal{spoly{T}}, p::spoly{T}, i::Int) where T <: Nemo.RingElem
   checkbounds(I, i)
   R = base_ring(I)
   GC.@preserve I R p begin
      p0 = libSingular.getindex(I.ptr, Cint(i - 1))
      if p0 != C_NULL
         libSingular.p_Delete(p0, R.ptr)
      end
      p1 = libSingular.p_Copy(p.ptr, R.ptr)
      libSingular.setindex_internal(I.ptr, p1, Cint(i - 1))
      nothing
   end
end

function getindex(I::sideal, i::Int)
   checkbounds(I, i)
   R = base_ring(I)
   GC.@preserve I p = libSingular.getindex(I.ptr, Cint(i - 1))
   GC.@preserve R return R(libSingular.p_Copy(p, R.ptr))
end

@doc Markdown.doc"""
    iszero(I::sideal)

Return `true` if the given ideal is algebraically the zero ideal.
"""
iszero(I::sideal) = Bool(libSingular.idIs0(I.ptr))

@doc Markdown.doc"""
    iszerodim(I::sideal)

Return `true` if the given ideal is zero dimensional, i.e. the Krull dimension of
$R/I$ is zero, where $R$ is the polynomial ring over which $I$ is an ideal..
"""
iszerodim(I::sideal) = Bool(libSingular.id_IsZeroDim(I.ptr, base_ring(I).ptr))

@doc Markdown.doc"""
    dimension(I::sideal{spoly{T}}) where T <: Nemo.RingElem

Given an ideal $I$ this function computes the Krull dimension
of the ring $R/I$, where $R$ is the polynomial ring over
which $I$ is an ideal. The ideal must be over a polynomial ring
and a Groebner basis.
"""
function dimension(I::sideal{spoly{T}}) where T <: Nemo.RingElem
   I.isGB == false && error("I needs to be a Groebner basis.")
   R = base_ring(I)
   # scDimIntRing does both fields and non-fields
   GC.@preserve I R return Int(libSingular.scDimIntRing(I.ptr, R.ptr))
end

@doc Markdown.doc"""
    isconstant(I::sideal)

Return `true` if the given ideal is a constant ideal, i.e. generated by constants in
the polynomial ring over which it is an ideal.
"""
isconstant(I::sideal) = Bool(libSingular.id_IsConstant(I.ptr, base_ring(I).ptr))

@doc Markdown.doc"""
    isvar_generated(I::sideal)

Return `true` if each generator in the representation of the ideal $I$ is a generator
of the polynomial ring, i.e. a variable.
"""
function isvar_generated(I::sideal)
   for i = 1:ngens(I)
      if !isgen(I[i])
         return false
      end
   end
   return true
end

@doc Markdown.doc"""
    normalize!(I::sideal)

Normalize the polynomial generators of the ideal $I$ in-place. This means to reduce
their coefficients to lowest terms. In most cases this does nothing, but if the
coefficient ring were the rational numbers for example, the coefficients of the
polynomials would be reduced to lowest terms.
"""
function normalize!(I::sideal)
   GC.@preserve I libSingular.id_Normalize(I.ptr, base_ring(I).ptr)
   nothing
end

function deepcopy_internal(I::sideal, dict::IdDict)
   R = base_ring(I)
   ptr = GC.@preserve I R libSingular.id_Copy(I.ptr, R.ptr)
   return Ideal(R, ptr)
end

function check_parent(I::sideal{T}, J::sideal{T}) where T <: Nemo.RingElem
   base_ring(I) != base_ring(J) && error("Incompatible ideals")
end

function hash(I::sideal, h::UInt)
   v = 0xebd7f23adcde5067%UInt
   for p in gens(I)
      v = xor(hash(p, h), v)
   end
   return v
end

###############################################################################
#
#   String I/O
#
###############################################################################

function show(io::IO, S::IdealSet)
   print(io, "Set of Singular Ideals over ")
   show(io, base_ring(S))
end

function show(io::IO, I::sideal)
   n = ngens(I)
   print(io, "Singular Ideal over ")
   show(io, base_ring(I))
   print(io, " with generators (")
   for i = 1:n
      show(io, I[i])
      if i != n
         print(io, ", ")
      end
   end
   print(io, ")")
end

###############################################################################
#
#   Arithmetic functions
#
###############################################################################

function (I::sideal{T} + J::sideal{T}) where T <: Nemo.RingElem
   check_parent(I, J)
   R = base_ring(I)
   ptr = GC.@preserve I J R libSingular.id_Add(I.ptr, J.ptr, R.ptr)
   return Ideal(R, ptr)
end

function (I::sideal{T} * J::sideal{T}) where T <: Nemo.RingElem
   check_parent(I, J)
   R = base_ring(I)
   ptr = GC.@preserve I J R libSingular.id_Mult(I.ptr, J.ptr, R.ptr)
   return Ideal(R, ptr)
end

function *(p::spoly{T}, I::sideal{spoly{T}}) where T <: Nemo.RingElem
   R = base_ring(I)
   R != parent(p) && error("Base rings do not match.")
   GC.@preserve I R p begin
      x = libSingular.id_Copy(I.ptr, R.ptr)
      y = libSingular.p_Copy(p.ptr, R.ptr)
      ptr = libSingular.id_MultP(x, y, R.ptr)
      return sideal{spoly{T}}(R, ptr)
   end
end

function *(I::sideal{spoly{T}}, p::spoly{T}) where T <: Nemo.RingElem
   return p*I
end

function *(i::Int, I::sideal{T}) where T <: Nemo.RingElem
   R = base_ring(I)
   return R(i) * I
end

function *(I::sideal{T}, i::Int) where T <: Nemo.RingElem
   R = base_ring(I)
   return R(i) * I
end

###############################################################################
#
#   Powering
#
###############################################################################

function ^(I::sideal, n::Int)
   (n > typemax(Cint) || n < 0) &&
      throw(DomainError(n, "exponent must be non-negative and <= $(typemax(Cint))"))
   R = base_ring(I)
   ptr = GC.@preserve I R libSingular.id_Power(I.ptr, Cint(n), R.ptr)
   return Ideal(R, ptr)
end

###############################################################################
#
#   Containment
#
###############################################################################

@doc Markdown.doc"""
    contains{T <: AbstractAlgebra.RingElem}(I::sideal{T}, J::sideal{T})

Returns `true` if the ideal $I$ contains the ideal $J$. This will be
expensive if $I$ is not a Groebner ideal, since its standard basis must be
computed.
"""
function contains(I::sideal{T}, J::sideal{T}) where T <: AbstractAlgebra.RingElem
   check_parent(I, J)
   if !I.isGB
      I = std(I)
   end
   return iszero(reduce(J, I))
end

###############################################################################
#
#   Comparison
#
###############################################################################

@doc Markdown.doc"""
    isequal{T <: AbstractAlgebra.RingElem}(I1::sideal{T}, I2::sideal{T})

Return `true` if the given ideals have the same generators in the same order. Note
that two algebraically equal ideals with different generators will return `false`.
"""
function isequal(I1::sideal{T}, I2::sideal{T}) where T <: AbstractAlgebra.RingElem
   check_parent(I1, I2)
   if ngens(I1) != ngens(I2)
      return false
   end
   R = base_ring(I1)
   GC.@preserve I1 I2 R return Bool(libSingular.id_IsEqual(I1.ptr, I2.ptr, R.ptr))
end

@doc Markdown.doc"""
    equal(I1::sideal{T}, I2::sideal{T}) where T <: AbstractAlgebra.RingElem

Return `true` if the two ideals are contained in each other, i.e. are the same
ideal mathematically. This function should be called only as a last
resort; it is exceptionally expensive to test equality of ideals! Do not
define `==` as an alias for this function!
"""
function equal(I1::sideal{T}, I2::sideal{T}) where T <: AbstractAlgebra.RingElem
   check_parent(I1, I2)
   return contains(I1, I2) && contains(I2, I1)
end

###############################################################################
#
#   Leading terms
#
###############################################################################

@doc Markdown.doc"""
    lead(I::sideal)

Return the ideal generated by the leading terms of the polynomials
generating $I$.
"""
function lead(I::sideal)
   R = base_ring(I)
   ptr = GC.@preserve I R libSingular.id_Head(I.ptr, R.ptr)
   return Ideal(R, ptr)
end

###############################################################################
#
#   Intersection
#
###############################################################################

@doc Markdown.doc"""
    intersection{T <: Nemo.RingElem}(I::sideal{T}, J::sideal{T})

Returns the intersection of the two given ideals.
"""
function intersection(I::sideal{T}, J::sideal{T}) where T <: Nemo.RingElem
   check_parent(I, J)
   R = base_ring(I)
   ptr = GC.@preserve I J R libSingular.id_Intersection(I.ptr, J.ptr, R.ptr)
   return Ideal(R, ptr)
end

function intersection(I::sideal{T}, Js::sideal{T}...) where T <: Nemo.RingElem
   R = base_ring(I)
   GC.@preserve I Js R begin
      CC = Ptr{Nothing}[I.ptr.cpp_object]
      for J in Js
         push!(CC, J.ptr.cpp_object)
      end
      GC.@preserve CC begin
         C_ptr = reinterpret(Ptr{Nothing}, pointer(CC))
         ptr = libSingular.id_MultSect(C_ptr, length(CC), R.ptr)
      end
      return Ideal(R, ptr)
   end
end

###############################################################################
#
#   Quotient
#
###############################################################################


@doc Markdown.doc"""
    quotient{T <: Nemo.RingElem}(I::sideal{T}, J::sideal{T})

Returns the quotient of the two given ideals. Recall that the ideal quotient
$(I:J)$ over a polynomial ring $R$ is defined by
$\{r \in R \;|\; rJ \subseteq I\}$.
"""
function quotient(I::sideal{T}, J::sideal{T}) where T <: Nemo.RingElem
   check_parent(I, J)
   R = base_ring(I)
   ptr = GC.@preserve I J R libSingular.id_Quotient(I.ptr, J.ptr, I.isGB, R.ptr)
   return Ideal(R, ptr)
end

###############################################################################
#
#   Saturation
#
###############################################################################

@doc Markdown.doc"""
    saturation{T <: Nemo.RingElem}(I::sideal{T}, J::sideal{T})

Returns the saturation of the ideal $I$ with respect to $J$, i.e. returns
the quotient ideal $(I:J^\infty)$ and the number of iterations.
"""
function saturation(I::sideal{T}, J::sideal{T}) where T <: Nemo.RingElem
   check_parent(I, J)
   R = base_ring(I)
   !has_global_ordering(R) && error("Must be over a ring with global ordering")
   Q = quotient(I, J)
   # we already have contains(Q, I) automatically
   k = 0
   while !contains(I, Q)
      I = Q
      Q = quotient(I, J)
      k = k + 1
   end
   return I,k
end

###############################################################################
#
#   Groebner basis
#
###############################################################################

@doc Markdown.doc"""
    slimgb(I::sideal; complete_reduction::Bool=false)

Given an ideal $I$ this function computes a Groebner basis for it.
Compared to `std`, `slimgb` uses different strategies for choosing
a reducer.
>
If the optional parameter `complete_reduction` is set to `true` the
function computes a reduced Gröbner basis for $I$.
"""
function slimgb(I::sideal; complete_reduction::Bool=false)
   R = base_ring(I)
   ptr = GC.@preserve I R libSingular.id_Slimgb(I.ptr, R.ptr,complete_reduction)
   libSingular.idSkipZeroes(ptr)
   z = Ideal(R, ptr)
   z.isGB = true
   return z
end

@doc Markdown.doc"""
    std(I::sideal; complete_reduction::Bool=false)

Compute a Groebner basis for the ideal $I$. Note that without
`complete_reduction` set to `true`, the generators of the Groebner basis
only have unique leading terms (up to permutation and multiplication by
constants). If `complete_reduction` is set to `true` (and the ordering is
a global ordering) then the Groebner basis is unique.
"""
function std(I::sideal; complete_reduction::Bool=false)
   R = base_ring(I)
   ptr = GC.@preserve I R libSingular.id_Std(I.ptr, R.ptr, complete_reduction)
   libSingular.idSkipZeroes(ptr)
   z = Ideal(R, ptr)
   z.isGB = true
   return z
end

@doc Markdown.doc"""
   satstd{T <: AbstractAlgebra.RingElem}(I::sideal{T}, J::sideal{T})
Given an ideal $J$ generated by variables, computes a standard basis of
`saturation(I, J)`. This is accomplished by dividing polynomials that occur
throughout the std computation by variables occuring in $J$, where possible.
Thus the result can be obtained faster than by first computing the saturation
and then the standard basis.
"""
function satstd(I::sideal{T}, J::sideal{T}) where T <: AbstractAlgebra.RingElem
   check_parent(I, J)
   !isvar_generated(J) && error("Second ideal must be generated by variables")
   R = base_ring(I)
   ptr = GC.@preserve I J R libSingular.id_Satstd(I.ptr, J.ptr, R.ptr)
   libSingular.idSkipZeroes(ptr)
   z = Ideal(R, ptr)
   z.isGB = true
   return z
end

@doc Markdown.doc"""
    fglm(I::sideal, ::Symbol)

Compute a Groebner basis for the zero - dimensional ideal $I$ in the ring $R$ using the FGLM
algorithm. All involved orderings have to be global.
"""
function fglm(I::sideal, ordering::Symbol)
   Rdest = base_ring(I)
   !has_global_ordering(Rdest) && error("Algorithm works only for global orderings")
   n = nvars(Rdest)
   Rsrc, = PolynomialRing(base_ring(Rdest), ["$i" for i in gens(Rdest)];
        ordering = ordering)
   !has_global_ordering(Rsrc) && error("Algorithm works only for global orderings")

   #Compute reduced Groebner basis in Rsrc
   phi = AlgebraHomomorphism(Rdest, Rsrc, [gen(Rsrc, i) for i in 1:n])
   Isrc = std(phi(I), complete_reduction = true)
   !iszerodim(Isrc) && error("Ideal needs to be zero-dimensional")

   ptr = GC.@preserve Isrc Rsrc Rdest libSingular.fglmzero(Isrc.ptr, Rsrc.ptr, Rdest.ptr)
   z = Ideal(Rdest, ptr)
   z.isGB = true
   return z
end

###############################################################################
#
#   Reduction
#
###############################################################################

@doc Markdown.doc"""
   reduce(I::sideal, G::sideal)
Return an ideal whose generators are the generators of $I$ reduced by the
ideal $G$. The ideal $G$ is required to be a Groebner basis. The returned
ideal will have the same number of generators as $I$, even if they are zero.
"""
function reduce(I::sideal, G::sideal)
   check_parent(I, G)
   R = base_ring(I)
   !G.isGB && error("Not a Groebner basis")
   ptr = GC.@preserve I G R libSingular.p_Reduce(I.ptr, G.ptr, R.ptr)
   return Ideal(R, ptr)
end

@doc Markdown.doc"""
    reduce(p::spoly, G::sideal)

Return the polynomial which is $p$ reduced by the polynomials generating $G$.
It is assumed that $G$ is a Groebner basis.
"""
function reduce(p::spoly, G::sideal)
   R = base_ring(G)
   par = parent(p)
   R != par && error("Incompatible base rings")
   !G.isGB && error("Not a Groebner basis")
   ptr = GC.@preserve p G R libSingular.p_Reduce(p.ptr, G.ptr, R.ptr)
   return par(ptr)
end

###############################################################################
#
#   Eliminate
#
###############################################################################

@doc Markdown.doc"""
    eliminate(I::sideal, polys::spoly...)

Given a list of polynomials which are variables, construct the ideal
corresponding geometrically to the projection of the variety given by the
ideal $I$ where those variables have been eliminated.
"""
function eliminate(I::sideal, polys::spoly...)
   R = base_ring(I)
   p = one(R)
   for i = 1:length(polys)
      !isgen(polys[i]) && error("Not a variable")
      parent(polys[i]) != R && error("Incompatible base rings")
      p *= polys[i]
   end
   ptr = GC.@preserve I p R libSingular.id_Eliminate(I.ptr, p.ptr, R.ptr)
   return Ideal(R, ptr)
end

#=
The kernel of the map \phi defined as follows:
Let v_1, ..., v_s be the variables in the polynomial ring 'source'. Then
\phi(v_i) := map[i].
This is internally computed via elimination.
=#
function kernel(source::PolyRing, map::sideal)
   # TODO: check for quotient rings and/or local (or mixed) orderings, see
   #       jjPREIMAGE() in the Singular interpreter
   target = base_ring(map)
   zero_ideal = Ideal(target, )
   ptr = GC.@preserve target map zero_ideal source libSingular.maGetPreimage(target.ptr, map.ptr, zero_ideal.ptr, source.ptr)
   return Ideal(source, ptr)
end

###############################################################################
#
#   Syzygies
#
###############################################################################

@doc Markdown.doc"""
    syz(I::sideal)

Compute the module of syzygies of the ideal.
"""
function syz(I::sideal)
   R = base_ring(I)
   ptr = GC.@preserve I R libSingular.id_Syzygies(I.ptr, R.ptr)
   libSingular.idSkipZeroes(ptr)
   return Module(R, ptr)
end

###############################################################################
#
#   LiftStd
#
###############################################################################

@doc Markdown.doc"""
    lift_std_syz(I::sdeal)

computes the Groebner base G of I, the transformation matrix T and the syzygies of M.
Returns G,T,S
(Matrix(G) = Matrix(I) * T, 0=Matrix(M)*Matrix(S))
"""
function lift_std_syz(M::sideal; complete_reduction::Bool = false)
   R = base_ring(M)
   ptr,T_ptr,S_ptr = GC.@preserve M R libSingular.id_LiftStdSyz(M.ptr, R.ptr, complete_reduction)
   return Ideal(R, ptr), smatrix{elem_type(R)}(R, T_ptr), Module(R,S_ptr)
end

@doc Markdown.doc"""
    lift_std(I::sideal)

computes the Groebner base G of I and the transformation matrix T such that
(Matrix(G) = Matrix(I) * T)
"""
function lift_std(M::sideal; complete_reduction::Bool = false)
   R = base_ring(M)
   ptr,T_ptr = GC.@preserve M R libSingular.id_LiftStd(M.ptr, R.ptr, complete_reduction)
   return Ideal(R, ptr), smatrix{elem_type(R)}(R, T_ptr)
end

###############################################################################
#
#   Resolutions
#
###############################################################################

@doc Markdown.doc"""
     fres{T <: Nemo.RingElem}(id::Union{sideal{T}, smodule{T}},
      max_length::Int, method::String="complete")
Compute a free resolution of the given ideal/module up to the maximum given
length. The ideal/module must be over a polynomial ring over a field, and
a Groebner basis.
The possible methods are "complete", "frame", "extended frame" and
"single module". The result is given as a resolution, whose i-th entry is
the syzygy module of the previous module, starting with the given
ideal/module.
The `max_length` can be set to $0$ if the full free resolution is required.
"""
function fres(id::Union{sideal{T}, smodule{T}}, max_length::Int, method::String = "complete") where T <: Nemo.RingElem
   id.isGB == false && error("input is not a standard basis")
   max_length < 0 && error("length for fres must not be negative")
   R = base_ring(id)
   if max_length == 0
        max_length = nvars(R)
        # TODO: consider qrings
   end
   if (method != "complete"
         && method != "frame"
         && method != "extended frame"
         && method != "single module")
      error("wrong optional argument for fres")
   end
   r, minimal = GC.@preserve id R libSingular.id_fres(id.ptr, Cint(max_length + 1), method, R.ptr)
   return sresolution{T}(R, r, Bool(minimal))
end

@doc Markdown.doc"""
     sres{T <: Nemo.RingElem}(id::sideal{T}, max_length::Int)
Compute a (free) Schreyer resolution of the given ideal up to the maximum
given length. The ideal must be over a polynomial ring over a field, and a
Groebner basis. The result is given as a resolution, whose i-th entry is
the syzygy module of the previous module, starting with the given ideal.
The `max_length` can be set to $0$ if the full free resolution is required.
"""
function sres(I::sideal{T}, max_length::Int) where T <: Nemo.RingElem
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
#   Ideal constructors
#
###############################################################################

function Ideal(R::PolyRing{T}, ids::spoly{T}...) where T <: Nemo.RingElem
   S = elem_type(R)
   length(ids) == 0 && return sideal{S}(R, R(0))
   return sideal{S}(R, ids...)
end

function Ideal(R::PolyRing{T}, ids::Array{spoly{T}, 1}) where T <: Nemo.RingElem
   S = elem_type(R)
   return sideal{S}(R, ids...)
end

function Ideal(R::PolyRing{T}, id::libSingular.ideal_ptr) where T <: Nemo.RingElem
   S = elem_type(R)
   return sideal{S}(R, id)
end

function (R::PolyRing{T})(id::libSingular.ideal_ptr) where T <: Nemo.RingElem
    return Ideal(R,id)
end

# maximal ideal in degree d
function MaximalIdeal(R::PolyRing{T}, d::Int) where T <: Nemo.RingElem
   (d > typemax(Cint) || d < 0) &&
      throw(DomainError(d, "degree must be non-negative and <= $(typemax(Cint))"))
   S = elem_type(R)
   ptr = GC.@preserve R libSingular.id_MaxIdeal(Cint(d), R.ptr)
   return sideal{S}(R, ptr)
end

###############################################################################
#
#   Differential functions
#
###############################################################################

@doc Markdown.doc"""
   jet(I::sideal, n::Int)
Given an ideal $I$ this function truncates the generators of $I$
up to degree $n$.
"""
function jet(I::sideal, n::Int)
   R = base_ring(I)
   ptr = GC.@preserve I R libSingular.id_Jet(I.ptr, Cint(n), R.ptr)
   return Ideal(R, ptr)
end

###############################################################################
#
#   Operations on zero-dimensional ideals
#
###############################################################################

@doc Markdown.doc"""
   vdim(I::sideal)
Given a zero-dimensional ideal $I$ this function computes the
dimension of the vector space $R/I$, where $R$ is the
polynomial ring over which $I$ is an ideal. The ideal must be
over a polynomial ring over a field, and a Groebner basis.
"""
function vdim(I::sideal)
   if I.isGB == false
      error("Ideal does not have a standard basis")
   elseif iszerodim == false
      error("Ideal is not zero-dimensional")
   else
      GC.@preserve I return libSingular.id_vdim(I.ptr, base_ring(I).ptr)
   end
end

@doc Markdown.doc"""
   kbase(I::sideal)
Given a zero-dimensional ideal $I$ this function computes a
vector space basis of the vector space $R/I$, where $R$ is the
polynomial ring over which $I$ is an ideal. The ideal must be
over a polynomial ring over a field, and a Groebner basis.
"""
function kbase(I::sideal)
   if I.isGB == false
      error("Ideal does not have a standard basis")
   elseif iszerodim == false
      error("Ideal is not zero-dimensional")
   else
      R = base_ring(I)
      ptr = GC.@preserve I R libSingular.id_kbase(I.ptr, R.ptr)
      return Ideal(R, ptr)
   end
end

@doc Markdown.doc"""
   highcorner(I::sideal)
Given a zero-dimensional ideal $I$ this function computes a
The highest corner of $I$. The output is a polynomial.
The ideal must be over a polynomial ring over a field, and
a Groebner basis.
"""
function highcorner(I::sideal)
   if I.isGB == false
      error("Ideal does not have a standard basis")
   elseif iszerodim==false
      error("Ideal is not zero-dimensional")
   else
      R = base_ring(I)
      ptr = GC.@preserve I R libSingular.id_highcorner(I.ptr, R.ptr)
      return R(ptr)
   end
end

###############################################################################
#
#   Functions for local rings
#
###############################################################################

@doc Markdown.doc"""
   minimal_generating_set(I::sideal)
Given an ideal $I$ in ring $R$ with local ordering, this returns an array
containing the minimal generators of $I$.
"""
function minimal_generating_set(I::sideal)
   R = base_ring(I)
   if has_global_ordering(R) || has_mixed_ordering(R)
      error("Ring needs local ordering.")
   end
   GC.@preserve I R return gens(Ideal(R, Singular.libSingular.idMinBase(I.ptr, R.ptr)))
end

###############################################################################
#
#   Independent sets
#
###############################################################################

@doc Markdown.doc"""
    independent_sets(I::sideal{spoly{T}}) where T <: Singular.FieldElem

Returns all non-extendable independent sets of $lead(I)$. $I$ has to be given
by a Groebner basis.
"""
function independent_sets(I::sideal{spoly{T}}) where T <: Nemo.FieldElem
   I.isGB == false && error("I needs to be a Groebner basis.")
   R = base_ring(I)
   n = nvars(R)
   a = Array{Int32, 1}()
   GC.@preserve I R libSingular.scIndIndset(I.ptr, R.ptr, a, true)
   m = Int(div(length(a), n))
   a = Int.(transpose(reshape(a, n, m)))
   P = Array{Array{spoly{T}, 1}, 1}()
   for i in 1:m
      b  = Array{spoly{T}, 1}()
      for j in findall(x->x == 1, a[i, :])
         push!(b, gen(R, j))
      end
      push!(P, b)
   end
   return P
end

@doc Markdown.doc"""
    maximal_independent_set(I::sideal{spoly{T}}; all::Bool = false) where T <: Nemo.FieldElem

Returns, by default, an array containing a maximal independet set of
$lead(I)$. $I$ has to be given by a Groebner basis.
If the additional parameter "all" is set to true, an array containing
all maximal independent sets of $lead(I)$ is returned.
"""
function maximal_independent_set(I::sideal{spoly{T}}; all::Bool = false) where T <: Nemo.FieldElem
   I.isGB == false && error("I needs to be a Groebner basis.")
   R = base_ring(I)
   d = dimension(I)
   if all == true
      P = Array{Array{spoly{T}, 1}, 1}()
      res = independent_sets(I)
      for i in 1:length(res)
         if length(res[i]) == d
            push!(P, res[i])
         end
      end
      return P
   else
      a = Array{Int32, 1}()
      GC.@preserve I R libSingular.scIndIndset(I.ptr, R.ptr, a, all)
      P = Array{spoly{T}, 1}()
      for j in findall(x->x == 1, a)
         push!(P, gen(R, j))
      end
      return P
   end
end
