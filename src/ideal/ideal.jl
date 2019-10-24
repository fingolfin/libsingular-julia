export sideal, IdealSet, syz, lead, normalize!, isconstant, iszerodim, fres,
       dimension, highcorner, jacobi, jet, kbase, minimal_generating_set,
       maximal_independent_set, ngens, sres, intersection, quotient,
       reduce, eliminate, kernel, equal, contains, isvar_generated, saturation,
       satstd, slimgb, std, vdim

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
> Return the number of generators in the internal representation of the ideal $I$.
"""
ngens(I::sideal) = Int(libSingular.ngens(I.ptr))

@doc Markdown.doc"""
    gens(I::sideal)
> Return the generators in the internal representation of the ideal $I$ as an array.
"""
function gens(I::sideal)
   return [I[i] for i in 1:Singular.ngens(I)]
end

function checkbounds(I::sideal, i::Int)
   (i > ngens(I) || i < 1) && throw(BoundsError(I, i))
end

function setindex!(I::sideal{spoly{T}}, p::spoly{T}, i::Int) where T <: Nemo.RingElem
   checkbounds(I, i)
   R = base_ring(I)
   p0 = libSingular.getindex(I.ptr, Cint(i - 1))
   if p0 != C_NULL
      libSingular.p_Delete(p0, R.ptr)
   end
   p1 = libSingular.p_Copy(p.ptr, R.ptr)
   libSingular.setindex_internal(I.ptr, p1, Cint(i - 1))
   nothing
end

function getindex(I::sideal, i::Int)
   checkbounds(I, i)
   R = base_ring(I)
   p = libSingular.getindex(I.ptr, Cint(i - 1))
   return R(libSingular.p_Copy(p, R.ptr))
end

@doc Markdown.doc"""
    iszero(I::sideal)
> Return `true` if the given ideal is algebraically the zero ideal.
"""
iszero(I::sideal) = Bool(libSingular.idIs0(I.ptr))

@doc Markdown.doc"""
    iszerodim(I::sideal)
> Return `true` if the given ideal is zero dimensional, i.e. the Krull dimension of
> $R/I$ is zero, where $R$ is the polynomial ring over which $I$ is an ideal..
"""
iszerodim(I::sideal) = Bool(libSingular.id_IsZeroDim(I.ptr, base_ring(I).ptr))

@doc Markdown.doc"""
    dimension(I::sideal{T})
> Given an ideal $I$ this function computes the Krull dimension
> of the ring $R/I$, where $R$ is the polynomial ring over
> which $I$ is an ideal. The ideal must be over a polynomial ring
> over a field, and a Groebner basis.
"""
function dimension(I::sideal{T}) where T <: Singular.RingElem
   I.isGB == false && error("I needs to be a Gröbner basis.")
   R = base_ring(I)
   !(typeof(base_ring(R)) <: Singular.Field) && 
     error("Polynomial ring has to be over a Singular field.")
   return Int(libSingular.scDimInt(I.ptr, R.ptr))
end

@doc Markdown.doc"""
    isconstant(I::sideal)
> Return `true` if the given ideal is a constant ideal, i.e. generated by constants in
> the polynomial ring over which it is an ideal.
"""
isconstant(I::sideal) = Bool(libSingular.id_IsConstant(I.ptr, base_ring(I).ptr))

@doc Markdown.doc"""
    isvar_generated(I::sideal)
> Return `true` if each generator in the representation of the ideal $I$ is a generator
> of the polynomial ring, i.e. a variable.
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
> Normalize the polynomial generators of the ideal $I$ in-place. This means to reduce
> their coefficients to lowest terms. In most cases this does nothing, but if the
> coefficient ring were the rational numbers for example, the coefficients of the
> polynomials would be reduced to lowest terms.
"""
function normalize!(I::sideal)
   libSingular.id_Normalize(I.ptr, base_ring(I).ptr)
   nothing
end

function deepcopy_internal(I::sideal, dict::IdDict)
   R = base_ring(I)
   ptr = libSingular.id_Copy(I.ptr, R.ptr)
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
   ptr = libSingular.id_Add(I.ptr, J.ptr, R.ptr)
   return Ideal(R, ptr)
end

function (I::sideal{T} * J::sideal{T}) where T <: Nemo.RingElem
   check_parent(I, J)
   R = base_ring(I)
   ptr = libSingular.id_Mult(I.ptr, J.ptr, R.ptr)
   return Ideal(R, ptr)
end

###############################################################################
#
#   Powering
#
###############################################################################

function ^(I::sideal, n::Int)
   (n > typemax(Cint) || n < 0) && throw(DomainError())
   R = base_ring(I)
   ptr = libSingular.id_Power(I.ptr, Cint(n), R.ptr)
   return Ideal(R, ptr)
end

###############################################################################
#
#   Containment
#
###############################################################################

@doc Markdown.doc"""
    contains{T <: AbstractAlgebra.RingElem}(I::sideal{T}, J::sideal{T})
> Returns `true` if the ideal $I$ contains the ideal $J$. This will be
> expensive if $I$ is not a Groebner ideal, since its standard basis must be
> computed.
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
> Return `true` if the given ideals have the same generators in the same order. Note
> that two algebraically equal ideals with different generators will return `false`.
"""
function isequal(I1::sideal{T}, I2::sideal{T}) where T <: AbstractAlgebra.RingElem
   check_parent(I1, I2)
   if ngens(I1) != ngens(I2)
      return false
   end
   R = base_ring(I1)
   return Bool(libSingular.id_IsEqual(I1.ptr, I2.ptr, R.ptr))
end

@doc Markdown.doc"""
    equal(I1::sideal{T}, I2::sideal{T}) where T <: AbstractAlgebra.RingElem
> Return `true` if the two ideals are contained in each other, i.e. are the same
> ideal mathematically. This function should be called only as a last
> resort; it is exceptionally expensive to test equality of ideals! Do not
> define `==` as an alias for this function!
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
> Return the ideal generated by the leading terms of the polynomials
> generating $I$.
"""
function lead(I::sideal)
   R = base_ring(I)
   ptr = libSingular.id_Head(I.ptr, R.ptr)
   return Ideal(R, ptr)
end

###############################################################################
#
#   Intersection
#
###############################################################################

@doc Markdown.doc"""
    intersection{T <: Nemo.RingElem}(I::sideal{T}, J::sideal{T})
> Returns the intersection of the two given ideals.
"""
function intersection(I::sideal{T}, J::sideal{T}) where T <: Nemo.RingElem
   check_parent(I, J)
   R = base_ring(I)
   ptr = libSingular.id_Intersection(I.ptr, J.ptr, R.ptr)
   return Ideal(R, ptr)
end

###############################################################################
#
#   Quotient
#
###############################################################################


@doc Markdown.doc"""
    quotient{T <: Nemo.RingElem}(I::sideal{T}, J::sideal{T})
> Returns the quotient of the two given ideals. Recall that the ideal quotient
> $(I:J)$ over a polynomial ring $R$ is defined by
> $\{r \in R \;|\; rJ \subseteq I\}$.
"""
function quotient(I::sideal{T}, J::sideal{T}) where T <: Nemo.RingElem
   check_parent(I, J)
   R = base_ring(I)
   ptr = libSingular.id_Quotient(I.ptr, J.ptr, I.isGB, R.ptr)
   return Ideal(R, ptr)
end

###############################################################################
#
#   Saturation
#
###############################################################################

@doc Markdown.doc"""
    saturation{T <: Nemo.RingElem}(I::sideal{T}, J::sideal{T})
> Returns the saturation of the ideal $I$ with respect to $J$, i.e. returns
> the quotient ideal $(I:J^\infty)$.
"""
function saturation(I::sideal{T}, J::sideal{T}) where T <: Nemo.RingElem
   check_parent(I, J)
   R = base_ring(I)
   !has_global_ordering(R) && error("Must be over a ring with global ordering")
   Q = quotient(I, J)
   # we already have contains(Q, I) automatically
   while !contains(I, Q)
      I = Q
      Q = quotient(I, J)
   end
   return I
end

###############################################################################
#
#   Groebner basis
#
###############################################################################

@doc Markdown.doc"""
   slimgb(I::sideal; complete_reduction::Bool=false)
> Given an ideal $I$ this function computes a Groebner basis for it.
> Compared to `std`, `slimgb` uses different strategies for choosing
> a reducer.
>
> If the optional parameter `complete_reduction` is set to `true` the
> function computes a reduced Gröbner basis for $I$.
"""
function slimgb(I::sideal; complete_reduction::Bool=false)
   R = base_ring(I)
   ptr = libSingular.id_Slimgb(I.ptr, R.ptr,complete_reduction)
   libSingular.idSkipZeroes(ptr)
   z = Ideal(R, ptr)
   z.isGB = true
   return z
end

@doc Markdown.doc"""
    std(I::sideal; complete_reduction::Bool=false)
> Compute a Groebner basis for the ideal $I$. Note that without
> `complete_reduction` set to `true`, the generators of the Groebner basis
> only have unique leading terms (up to permutation and multiplication by
> constants). If `complete_reduction` is set to `true` (and the ordering is
> a global ordering) then the Groebner basis is unique.
"""
function std(I::sideal; complete_reduction::Bool=false)
   R = base_ring(I)
   ptr = libSingular.id_Std(I.ptr, R.ptr, complete_reduction)
   libSingular.idSkipZeroes(ptr)
   z = Ideal(R, ptr)
   z.isGB = true
   return z
end

@doc Markdown.doc"""
   satstd{T <: AbstractAlgebra.RingElem}(I::sideal{T}, J::sideal{T})
> Given an ideal $J$ generated by variables, computes a standard basis of
> `saturation(I, J)`. This is accomplished by dividing polynomials that occur
> throughout the std computation by variables occuring in $J$, where possible.
> Thus the result can be obtained faster than by first computing the saturation
> and then the standard basis.
"""
function satstd(I::sideal{T}, J::sideal{T}) where T <: AbstractAlgebra.RingElem
   check_parent(I, J)
   !isvar_generated(J) && error("Second ideal must be generated by variables")
   R = base_ring(I)
   ptr = libSingular.id_Satstd(I.ptr, J.ptr, R.ptr)
   libSingular.idSkipZeroes(ptr)
   z = Ideal(R, ptr)
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
> Return an ideal whose generators are the generators of $I$ reduced by the
> ideal $G$. The ideal $G$ is required to be a Groebner basis. The returned
> ideal will have the same number of generators as $I$, even if they are zero.
"""
function reduce(I::sideal, G::sideal)
   check_parent(I, G)
   R = base_ring(I)
   !G.isGB && error("Not a Groebner basis")
   ptr = libSingular.p_Reduce(I.ptr, G.ptr, R.ptr)
   return Ideal(R, ptr)
end

@doc Markdown.doc"""
    reduce(p::spoly, G::sideal)
> Return the polynomial which is $p$ reduced by the polynomials generating $G$.
> It is assumed that $G$ is a Groebner basis.
"""
function reduce(p::spoly, G::sideal)
   R = base_ring(G)
   par = parent(p)
   R != par && error("Incompatible base rings")
   !G.isGB && error("Not a Groebner basis")
   ptr = libSingular.p_Reduce(p.ptr, G.ptr, R.ptr)
   return par(ptr)
end

###############################################################################
#
#   Eliminate
#
###############################################################################

@doc Markdown.doc"""
    eliminate(I::sideal, polys::spoly...)
> Given a list of polynomials which are variables, construct the ideal
> corresponding geometrically to the projection of the variety given by the
> ideal $I$ where those variables have been eliminated.
"""
function eliminate(I::sideal, polys::spoly...)
   R = base_ring(I)
   p = one(R)
   for i = 1:length(polys)
      !isgen(polys[i]) && error("Not a variable")
      parent(polys[i]) != R && error("Incompatible base rings")
      p *= polys[i]
   end
   ptr = libSingular.id_Eliminate(I.ptr, p.ptr, R.ptr)
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
   ptr = libSingular.maGetPreimage(target.ptr, map.ptr, zero_ideal.ptr, source.ptr)
   return Ideal(source, ptr)
end

###############################################################################
#
#   Syzygies
#
###############################################################################

@doc Markdown.doc"""
    syz(I::sideal)
> Compute the module of syzygies of the ideal.
"""
function syz(I::sideal)
   R = base_ring(I)
   ptr = libSingular.id_Syzygies(I.ptr, R.ptr)
   libSingular.idSkipZeroes(ptr)
   return Module(R, ptr)
end

###############################################################################
#
#   Resolutions
#
###############################################################################

@doc Markdown.doc"""
     fres{T <: Nemo.RingElem}(id::Union{sideal{T}, smodule{T}},
      max_length::Int, method::String="complete")
> Compute a free resolution of the given ideal/module up to the maximum given
> length. The ideal/module must be over a polynomial ring over a field, and
> a Groebner basis.
> The possible methods are "complete", "frame", "extended frame" and
> "single module". The result is given as a resolution, whose i-th entry is
> the syzygy module of the previous module, starting with the given
> ideal/module.
> The `max_length` can be set to $0$ if the full free resolution is required.
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
   r, minimal = libSingular.id_fres(id.ptr, Cint(max_length + 1), method, R.ptr)
   return sresolution{T}(R, r, minimal)
end

@doc Markdown.doc"""
     sres{T <: Nemo.RingElem}(id::sideal{T}, max_length::Int)
> Compute a (free) Schreyer resolution of the given ideal up to the maximum
> given length. The ideal must be over a polynomial ring over a field, and a
> Groebner basis. The result is given as a resolution, whose i-th entry is
> the syzygy module of the previous module, starting with the given ideal.
> The `max_length` can be set to $0$ if the full free resolution is required.
"""
function sres(I::sideal{T}, max_length::Int) where T <: Nemo.RingElem
   I.isGB == false && error("Not a Groebner basis ideal")
   R = base_ring(I)
   if max_length == 0
        max_length = nvars(R)
        # TODO: consider qrings
   end
   r, minimal = libSingular.id_sres(I.ptr, Cint(max_length + 1), R.ptr)
   return sresolution{T}(R, r, minimal)
end

###############################################################################
#
#   Ideal constructors
#
###############################################################################

function Ideal(R::PolyRing{T}, ids::spoly{T}...) where T <: Nemo.RingElem
   S = elem_type(R)
   return sideal{S}(R, ids...)
end

function Ideal(R::PolyRing{T}, ids::Array{spoly{T}, 1}) where T <: Nemo.RingElem
   S = elem_type(R)
   return sideal{S}(R, ids...)
end

function Ideal(R::PolyRing{T}, id::libSingular.ideal) where T <: Nemo.RingElem
   S = elem_type(R)
   return sideal{S}(R, id)
end

function (R::PolyRing{T})(id::libSingular.ideal) where T <: Nemo.RingElem
    return Ideal(R,id)
end

# maximal ideal in degree d
function MaximalIdeal(R::PolyRing{T}, d::Int) where T <: Nemo.RingElem
   (d > typemax(Cint) || d < 0) && throw(DomainError())
   S = elem_type(R)
   ptr = libSingular.id_MaxIdeal(Cint(d), R.ptr)
   return sideal{S}(R, ptr)
end

###############################################################################
#
#   Differential functions
#
###############################################################################

@doc Markdown.doc"""
   jet(I::sideal, n::Int)
> Given an ideal $I$ this function truncates the generators of $I$
> up to degree $n$.
"""
function jet(I::sideal, n::Int)
   J = deepcopy(I)
   J.ptr = libSingular.id_Jet(I.ptr, Cint(n), base_ring(I).ptr)
   return J
end

@doc Markdown.doc"""
   jacobi(I::sideal)
> Given an ideal $I$ this function computes the jacobi matrix of
> the generatos of $I$. The output is a matrix object.
"""
function jacobi(I::sideal)
   R = base_ring(I)
   n = nvars(R)
   m = ngens(I)
   J = zero_matrix(R, m, n)
   for i in 1:m
      for j in 1:n
         J[i, j] = derivative(I[i], j)
      end
   end
   return J
end

###############################################################################
#
#   Operations on zero-dimensional ideals
#
###############################################################################

@doc Markdown.doc"""
   vdim(I::sideal)
> Given a zero-dimensional ideal $I$ this function computes the
> dimension of the vector space $R/I$, where $R$ is the
> polynomial ring over which $I$ is an ideal. The ideal must be
> over a polynomial ring over a field, and a Groebner basis.
"""
function vdim(I::sideal)
   if I.isGB == false
      error("Ideal does not have a standard basis")
   elseif iszerodim == false
      error("Ideal is not zero-dimensional")
   else
      libSingular.id_vdim(I.ptr, base_ring(I).ptr)
   end
end

@doc Markdown.doc"""
   kbase(I::sideal)
> Given a zero-dimensional ideal $I$ this function computes a
> vector space basis of the vector space $R/I$, where $R$ is the
> polynomial ring over which $I$ is an ideal. The ideal must be
> over a polynomial ring over a field, and a Groebner basis.
"""
function kbase(I::sideal)
   if I.isGB == false
      error("Ideal does not have a standard basis")
   elseif iszerodim == false
      error("Ideal is not zero-dimensional")
   else
      K = deepcopy(I)
      K.ptr = libSingular.id_kbase(I.ptr, base_ring(I).ptr)
      return K
   end
end

@doc Markdown.doc"""
   highcorner(I::sideal)
> Given a zero-dimensional ideal $I$ this function computes a
> The highest corner of $I$. The output is a polynomial.
> The ideal must be over a polynomial ring over a field, and
> a Groebner basis.
"""
function highcorner(I::sideal)
   if I.isGB == false
      error("Ideal does not have a standard basis")
   elseif iszerodim==false
      error("Ideal is not zero-dimensional")
   else
      K = deepcopy(I[1])
      K.ptr = libSingular.id_highcorner(I.ptr, base_ring(I).ptr)
      return K
   end
end

###############################################################################
#
#   Functions for local rings
#
###############################################################################

@doc Markdown.doc"""
   minimal_generating_set(I::sideal)
> Given an ideal $I$ in ring $R$ with local ordering, this returns an array
> containing the minimal generators of $I$.
"""
function minimal_generating_set(I::sideal)
   R = base_ring(I)
   if has_global_ordering(R) || has_mixed_ordering(R)
      error("Ring needs local ordering.")
   end
   return gens(Ideal(R, Singular.libSingular.idMinBase(I.ptr, R.ptr)))
end

###############################################################################
#
#   Maximal independent set
#
###############################################################################

@doc Markdown.doc"""
    maximal_independent_set{I::sideal{T}; all::Bool = false)
> Returns, by default, an array containing a maximal independet set of
> $lead(I)$. $I$ has to be given by a Gröbner basis.
> If the additional parameter "all" is set to true, an array containing
> all maximal independent sets iof $lead(I)$ is returned.
"""
function maximal_independent_set(I::sideal{T}; all::Bool = false) where T <: Singular.RingElem
   I.isGB == false && error("I needs to be a Gröbner basis.")
   R = base_ring(I)
   !(typeof(base_ring(R)) <: Singular.Field) && 
       error("Polynomial ring has to be over a Singular field.")
   n = nvars(R)
   a = Array{Int32, 1}()
   libSingular.scIndIndset(I.ptr, R.ptr, a, all)
   if all == true
      m = Int(length(a)/n)
      a = Int.(transpose(reshape(a, n, m)))
      P = Array{Array{spoly, 1}, 1}()
      for i in 1:m
         b  = Array{spoly, 1}()
         for j in findall(x->x==1, a[i, :])
            push!(b, gen(R, j))
         end
         push!(P, b)
      end
      return P
   else
      P = Array{spoly, 1}()
      for j in findall(x->x==1, a)
         push!(P, gen(R, j))
      end
      return P
   end
end
 
