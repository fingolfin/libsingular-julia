function ncols(I::matrix) 
  icxx"""(int) MATCOLS($I);"""
end

function nrows(I::matrix) 
  icxx"""(int) MATROWS($I);"""
end

function id_Module2Matrix(I::ideal, R::ring)
   icxx"""id_Module2Matrix($I, $R);"""
end

function getindex(M::matrix, i::Cint, j::Cint) 
  icxx"""(poly) MATELEM($M, $i, $j);"""
end

function mp_Delete(M::matrix, R::ring)
   icxx"""mp_Delete(&$M, $R);"""
end

function mp_Add(M::matrix, N::matrix, R::ring)
   icxx"""mp_Add($M, $N, $R);"""
end

function mp_Sub(M::matrix, N::matrix, R::ring)
   icxx"""mp_Sub($M, $N, $R);"""
end

function mp_Mult(M::matrix, N::matrix, R::ring)
   icxx"""mp_Mult($M, $N, $R);"""
end

function iiStringMatrix(I::matrix, d::Cint, R::ring)
   icxx"""iiStringMatrix($I, $d, $R);"""
end
