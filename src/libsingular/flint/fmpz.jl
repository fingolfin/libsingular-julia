###############################################################################
#
#   Memory management
#
###############################################################################

function fmpzInit(i::Clong, cf::coeffs)
   return number(Nemo.fmpz(i))
end
   
function fmpzDelete(ptr::Ptr{number}, cf::coeffs)
   n = unsafe_load(ptr)
   if n != C_NULL
      number_pop!(nemoNumberID, Ptr{Void}(n))
   end
   nothing
end

function fmpzCopy(a::number, cf::coeffs)
   n = julia(a)::Nemo.fmpz
   return number(deepcopy(n))
end

###############################################################################
#
#   Printing
#
###############################################################################

function fmpzGreaterZero(a::number, cf::coeffs)
   n = julia(a)::Nemo.fmpz
   return Cint(n > 0)
end

function fmpzCoeffWrite(cf::coeffs, d::Cint)
   r = julia(cf)::Nemo.FlintIntegerRing
   str = string(r)
   icxx"""PrintS($str);"""
   nothing
end

function fmpzWrite(a::number, cf::coeffs)
   n = julia(a)::Nemo.fmpz
   if needs_parentheses(n)
      str = "("*string(n)*")"
   else
      str = string(n)
   end
   icxx"""StringAppendS($str);"""
   nothing
end

###############################################################################
#
#   Arithmetic
#
###############################################################################

function fmpzNeg(a::number, cf::coeffs)
   n = julia(a)::Nemo.fmpz
   return number(-n)
end

function fmpzInpNeg(a::number, cf::coeffs)
   n = julia(a)::Nemo.fmpz
   ccall((:fmpz_neg, :libflint), Void, (Ptr{Nemo.fmpz}, Ptr{Nemo.fmpz}), &n, &n)
   return number(n, false)
end

function fmpzInvers(a::number, cf::coeffs)
   n = julia(a)::Nemo.fmpz
   return number(divexact(1, n))
end

function fmpzMult(a::number, b::number, cf::coeffs)
   n1 = julia(a)::Nemo.fmpz
   n2 = julia(b)::Nemo.fmpz
   return number(n1*n2)
end

function fmpzInpMult(a::Ptr{number}, b::number, cf::coeffs)
   r = unsafe_load(a)
   aa = julia(r)::Nemo.fmpz
   bb = julia(b)::Nemo.fmpz
   ptr1 = pointer_from_objref(aa)
   aa = mul!(aa, aa, bb)
   ptr2 = pointer_from_objref(aa)
   n = number(aa, ptr1 != ptr2)
   unsafe_store!(a, n, 1)
   nothing
end

function fmpzAdd(a::number, b::number, cf::coeffs)
   n1 = julia(a)::Nemo.fmpz
   n2 = julia(b)::Nemo.fmpz
   return number(n1 + n2)
end

function fmpzInpAdd(a::Ptr{number}, b::number, cf::coeffs)
   r = unsafe_load(a)
   aa = julia(r)::Nemo.fmpz
   bb = julia(b)::Nemo.fmpz
   ptr1 = pointer_from_objref(aa)
   aa = addeq!(aa, bb)
   ptr2 = pointer_from_objref(aa)
   n = number(aa, ptr1 != ptr2)
   unsafe_store!(a, n, 1)
   nothing
end

function fmpzSub(a::number, b::number, cf::coeffs)
   n1 = julia(a)::Nemo.fmpz
   n2 = julia(b)::Nemo.fmpz
   return number(n1 - n2)
end

function fmpzDiv(a::number, b::number, cf::coeffs)
   n1 = julia(a)::Nemo.fmpz
   n2 = julia(b)::Nemo.fmpz
   return number(divexact(n1, n2))
end

###############################################################################
#
#   Comparison
#
###############################################################################

function fmpzGreater(a::number, b::number, cf::coeffs)
   n1 = julia(a)::Nemo.fmpz
   n2 = julia(b)::Nemo.fmpz
   return Cint(n1 > n2)
end

function fmpzEqual(a::number, b::number, cf::coeffs)
   n1 = julia(a)::Nemo.fmpz
   n2 = julia(b)::Nemo.fmpz
   return Cint(n1 == n2)
end

function fmpzIsZero(a::number, cf::coeffs)
   n = julia(a)::Nemo.fmpz
   return Cint(iszero(n))
end

function fmpzIsOne(a::number, cf::coeffs)
   n = julia(a)::Nemo.fmpz
   return Cint(isone(n))
end

function fmpzIsMOne(a::number, cf::coeffs)
   n = julia(a)::Nemo.fmpz
   return Cint(n == -1)
end

###############################################################################
#
#   GCD
#
###############################################################################

function fmpzGcd(a::number, b::number, cf::coeffs)
   n1 = julia(a)::Nemo.fmpz
   n2 = julia(b)::Nemo.fmpz
   return number(gcd(n1, n2))
end

###############################################################################
#
#   Extended GCD
#
###############################################################################

function fmpzExtGcd(a::number, b::number, s::Ptr{number}, t::Ptr{number}, cf::coeffs)
   n1 = julia(a)::Nemo.fmpz
   n2 = julia(b)::Nemo.fmpz
   s1 = unsafe_load(s)
   if s1 != C_NULL
      number_pop!(nemoNumberID, Ptr{Void}(s1))
   end
   t1 = unsafe_load(t)
   if t1 != C_NULL
      number_pop!(nemoNumberID, Ptr{Void}(t1))
   end
   g1, s1, t1 = gcdx(n1, n2)
   libSingular.setindex!(s, number(s1))
   libSingular.setindex!(t, number(t1))
   return number(g1)
end

###############################################################################
#
#   Conversion
#
###############################################################################

function fmpzInt(ptr::Ptr{number}, cf::coeffs)
   n = julia(unsafe_load(ptr))::fmpz
   return Clong(n)
end

function fmpzMPZ(b::BigInt, ptr::Ptr{number}, cf::coeffs)
   n = julia(unsafe_load(ptr))::fmpz
   z = convert(BigInt, n)
   bptr = pointer_from_objref(b)
   zptr = pointer_from_objref(z)
   icxx"""mpz_init_set((__mpz_struct *) $bptr, (mpz_ptr) $zptr);"""
   nothing
end

###############################################################################
#
#   InitChar
#
###############################################################################

function fmpzInitChar(cf::coeffs, p::Ptr{Void})
        
    pInit = cfunction(fmpzInit, number, (Clong, coeffs))
    pInt = cfunction(fmpzInt, Clong, (Ptr{number}, coeffs))
    pMPZ = cfunction(fmpzMPZ, Void, (BigInt, Ptr{number}, coeffs))
    pInpNeg = cfunction(fmpzInpNeg, number, (number, coeffs))
    pCopy = cfunction(fmpzCopy, number, (number, coeffs))
    pDelete = cfunction(fmpzDelete, Void, (Ptr{number}, coeffs))
    pAdd = cfunction(fmpzAdd, number, (number, number, coeffs))
    pInpAdd = cfunction(fmpzInpAdd, Void, (Ptr{number}, number, coeffs))
    pSub = cfunction(fmpzSub, number, (number, number, coeffs))
    pMult = cfunction(fmpzMult, number, (number, number, coeffs))
    pInpMult = cfunction(fmpzInpMult, Void, (Ptr{number}, number, coeffs))
    pDiv = cfunction(fmpzDiv, number, (number, number, coeffs))
    pInvers = cfunction(fmpzInvers, number, (number, coeffs))
    pGcd = cfunction(fmpzGcd, number, (number, number, coeffs))
    pExtGcd = cfunction(fmpzExtGcd, number, (number, number, Ptr{number}, Ptr{number}, coeffs))
    pGreater = cfunction(fmpzGreater, Cint, (number, number, coeffs))
    pEqual = cfunction(fmpzEqual, Cint, (number, number, coeffs))
    pIsZero = cfunction(fmpzIsZero, Cint, (number, coeffs))
    pIsOne = cfunction(fmpzIsOne, Cint, (number, coeffs))
    pIsMOne = cfunction(fmpzIsMOne, Cint, (number, coeffs))
    pGreaterZero = cfunction(fmpzGreaterZero, Cint, (number, coeffs))
    pWrite = cfunction(fmpzWrite, Void, (number, coeffs))
    pCoeffWrite = cfunction(fmpzCoeffWrite, Void, (coeffs, Cint))

    icxx""" 
      coeffs cf = (coeffs)($cf);
      cf->has_simple_Alloc = FALSE;  
      cf->has_simple_Inverse= FALSE;          
      cf->is_field  = FALSE;
      cf->is_domain = TRUE;
      cf->ch = 0;
      cf->data = $p;
      cf->cfInit = (number (*)(long, const coeffs)) $pInit;
      cf->cfInt = (long (*)(number &, const coeffs)) $pInt;
      cf->cfMPZ = (void (*)(__mpz_struct *, number &, const coeffs)) $pMPZ;
      cf->cfInpNeg = (number (*)(number, const coeffs)) $pInpNeg;
      cf->cfCopy = (number (*)(number, const coeffs)) $pCopy;
      cf->cfDelete = (void (*)(number *, const coeffs)) $pDelete;
      cf->cfAdd = (numberfunc) $pAdd;
      cf->cfInpAdd = (void (*)(number &, number, const coeffs)) $pInpAdd;
      cf->cfSub = (numberfunc) $pSub;
      cf->cfMult = (numberfunc) $pMult;
      cf->cfInpMult = (void (*)(number &, number, const coeffs)) $pInpMult;
      cf->cfDiv = (numberfunc) $pDiv;
      cf->cfInvers = (number (*)(number, const coeffs)) $pInvers;
      cf->cfGcd = (numberfunc) $pGcd;
      cf->cfExtGcd = (number (*)(number, number, number *, number *, const coeffs)) $pExtGcd;
      cf->cfGreater = (BOOLEAN (*)(number, number, const coeffs)) $pGreater;
      cf->cfEqual = (BOOLEAN (*)(number, number, const coeffs)) $pEqual;
      cf->cfIsZero = (BOOLEAN (*)(number, const coeffs)) $pIsZero;
      cf->cfIsOne = (BOOLEAN (*)(number, const coeffs)) $pIsOne;
      cf->cfIsMOne = (BOOLEAN (*)(number, const coeffs)) $pIsMOne;
      cf->cfGreaterZero = (BOOLEAN (*)(number, const coeffs)) $pGreaterZero;
      cf->cfWriteLong = (void (*)(number, const coeffs)) $pWrite;
      cf->cfCoeffWrite = (void (*)(const coeffs, BOOLEAN)) $pCoeffWrite;
    """

    return Cint(0)
end

function register(R::FlintIntegerRing)
   c = cfunction(fmpzInitChar, Cint, (coeffs, Ptr{Void}))
   ptr = @cxx n_unknown
   return nRegister(ptr, c)
end
