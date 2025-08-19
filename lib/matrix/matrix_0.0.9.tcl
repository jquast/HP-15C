# ------------------------------------------------------------------------------
#
#                   Matrix Package for the HP-15C Simulator
#
#                          (c) 2017-2018 Torsten Manz
#
# ------------------------------------------------------------------------------
#
# This package is based partly on the tcllib Linear Algebra Package(linalg.tcl).
# The routines have been heavily modified to work as part of the HP-15C
# Simulator. This package is not meant to be used outside the HP-15C simulator.
#
# ------------------------------------------------------------------------------
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, see <http://www.gnu.org/licenses/>
#
# ------------------------------------------------------------------------------

package require Tcl 8
package provide matrix 0.0.9
package require s56b

namespace eval ::matrix {

  variable OVERFLOW 0

}

# ------------------------------------------------------------------------------
# Matrix creation

# ------------------------------------------------------------------------------
proc ::matrix::mkVector { ndim {value 0.0} } {

  set new {}
  while { $ndim > 0 } {
    lappend new $value
    incr ndim -1
  }

  return $new

}

# ------------------------------------------------------------------------------
proc ::matrix::mkMatrix { nrows ncols {value 0.0} } {

  set new {}
  while { $nrows > 0 } {
    lappend new [mkVector $ncols $value]
    incr nrows -1
  }

  return $new

}

# ------------------------------------------------------------------------------
proc ::matrix::mkIdentity { size } {

  set new [mkMatrix $size $size 0.0]
  while { $size > 0 } {
    incr size -1
    lset new $size $size 1.0
  }

  return $new

}

# ------------------------------------------------------------------------------
proc ::matrix::Dim { mat rows cols } {

  if {$rows == 0 || $cols == 0} {
    set new [mkMatrix 0 0 0.0]
  } elseif {[Rows $mat] != $rows || [Cols $mat] != $cols} {
# Re-size matrix
    set new [mkMatrix $rows $cols 0.0]
    set old [join $mat]
    set rr 0
    set cc 0
    foreach ov $old {
      SetElem new $rr $cc $ov
      incr cc
      if {$cc >= $cols} {
        set cc 0
        incr rr
        if {$rr >= $rows} {
          break
        }
      }
    }
  } else {
    set new [mkMatrix $rows $cols 0.0]
  }

  return $new

}

# ------------------------------------------------------------------------------
# Properties

# ------------------------------------------------------------------------------
proc ::matrix::Rows { mat } {

  return [llength $mat]

}

# ------------------------------------------------------------------------------
proc ::matrix::Cols { mat } {

  return [llength [lindex $mat 0]]

}

# ------------------------------------------------------------------------------
proc ::matrix::Shape { obj } {

  set rc [llength $obj]
  if { [llength [lindex $obj 0]] > 1 } {
    lappend rc [llength [lindex $obj 0]]
  }

  return $rc

}

# ------------------------------------------------------------------------------
proc ::matrix::MorV { obj } {

  if { [llength $obj] > 1 } {
    if { [llength [lindex $obj 0]] > 1 } {
      return "M"
    } else {
      return "C"
    }
  } else {
    if { [llength [lindex $obj 0]] > 1 } {
      return "R"
    } else {
      return "S"
    }
  }

}

# ------------------------------------------------------------------------------
proc ::matrix::Equal { mat1 mat2 } {

  set rc 1
  foreach row1 $mat1 row2 $mat2 {
    foreach elm1 $row1 elm2 $row2 {
      if {[expr $elm1*1.0 != $elm2*1.0]} {
        set rc 0
        break
      }
    }
  }

  return $rc

}

# ------------------------------------------------------------------------------
proc ::matrix::Conforming { type obj1 obj2 } {

  lassign [Shape $obj1] row1 col1
  lassign [Shape $obj2] row2 col2

  set rc 0
  switch $type {
    "shape" {
      set rc [expr {$row1 == $row2 && $col1 == $col2}]
    }
    "matmul" {
      if {$col1 == ""} {set col1 1}
      if {$row2 == ""} {set row2 1}
      set rc [expr {$col1 == $row2}]
    }
    "rows" {
      set rc [expr {$row1 == $row2}]
    }
  }

  return $rc

}

# ------------------------------------------------------------------------------
# Non-destructive operations

# ------------------------------------------------------------------------------
proc ::matrix::dger { matrix alpha x y {scope ""}} {

  upvar $matrix mat
  set nrows [llength $mat]
  set ncols $nrows
  if {$scope==""} then {
    set imin 0
    set imax [expr {$nrows - 1}]
    set jmin 0
    set jmax [expr {$ncols - 1}]
  } else {
    foreach {imin imax jmin jmax} $scope {break}
  }
  set xy [matmul $x $y]
  set alphaxy [ScalarOpMat $alpha $xy "*"]
  for { set iline $imin } { $iline <= $imax } { incr iline } {
    set ilineshift [expr {$iline - $imin}]
    set matiline [lindex $mat $iline]
    set alphailine [lindex $alphaxy $ilineshift]
    for { set icol $jmin } { $icol <= $jmax } { incr icol } {
      set icolshift [expr {$icol - $jmin}]
      set aij [lindex $matiline $icol]
      set shift [lindex $alphailine $icolshift]
      SetElem mat $iline $icol [expr {$aij + $shift}]
    }
  }

  return $mat

}

# ------------------------------------------------------------------------------
proc ::matrix::dgetrf { matrix } {

  upvar $matrix mat
  set norows [llength $mat]
  set nocols $norows

  # Initialize permutation
  set nm1 [expr {$norows - 1}]
  set ipiv {}
  # Perform Gauss transforms
  for { set k 0 } { $k < $nm1 } { incr k } {
    # Search pivot in column n, from lines k to n
    set column [GetCol $mat $k $k $nm1]
    foreach {abspivot murel} [NormMax $column 1] {break}
    # Shift mu, because max returns with respect to the column (k:n,k)
    set mu [expr {$murel + $k}]
    # Swap lines k and mu from columns 1 to n
    SwapRows mat $k $mu
    set akk [lindex $mat $k $k]
    # Store permutation
    lappend ipiv $mu
    # Store pivots for lines k+1 to n in columns k+1 to n
    set kp1 [expr {$k+1}]
    set akp1 [GetCol $mat $k $kp1 $nm1]
    set mult [expr {1. / double($akk)}]
    set akp1 [ScalarOpMat $mult $akp1 "*"]
    SetCol mat $k $akp1 $kp1 $nm1
    # Perform transform for lines k+1 to n
    set akp1k [GetCol $mat $k $kp1 $nm1]
    set akkp1 [lrange [lindex $mat $k] $kp1 $nm1]
    set scope [list $kp1 $nm1 $kp1 $nm1]
    dger mat -1. $akp1k $akkp1 $scope
  }

  return $ipiv

}

# ------------------------------------------------------------------------------
proc ::matrix::Det { mat {ipiv {}} } {

  if {[llength $ipiv] == 0 } then {
    set ipiv [dgetrf mat]
  }
  set det 1.0
  set norows [llength $mat]
  set i 0
  foreach row $mat {
    set uu [lindex $row $i]
    set det [expr {$det * $uu}]
    if { $i < $norows - 1 } then {
      set ii [lindex $ipiv $i]
      if { $ii != $i } then {
        set det [expr {-1.0 * $det}]
      }
    }
    incr i
  }

  return [list $det $ipiv]

}

# ------------------------------------------------------------------------------
proc ::matrix::EuclideanNorm { mat } {

  set eucnorm 0.0
  foreach row $mat {
    foreach elm $row {
      set eucnorm [expr {$eucnorm + ($elm * $elm)}]
    }
  }

  return [expr sqrt($eucnorm)]

}

# ------------------------------------------------------------------------------
proc ::matrix::RowNorm { mat } {

  set rownorm 0.0
  foreach row $mat {
    set rnorm 0.0
    foreach elm $row {
      set rnorm [expr {$rnorm + abs($elm)}]
    }
    if {$rnorm > $rownorm} {
      set rownorm $rnorm
    }
  }

  return $rownorm

}

# ------------------------------------------------------------------------------
proc ::matrix::NormMax { vector {index 0} } {

  set max [lindex $vector 0]
  set imax 0
  set ii 0
  foreach elm $vector {
    if {[expr {abs($elm) > $max}]} then {
      set max [expr {abs($elm)}]
      set imax $ii
    }
    incr ii
  }
  if {$index == 0} then {
    set rc $max
  } else {
    set rc [list $max $imax]
  }

  return $rc

}

# ------------------------------------------------------------------------------
# Getting and setting matrix elements

# ------------------------------------------------------------------------------
proc ::matrix::GetElem { mat row col } {

  return [lindex $mat $row $col]

}

# ------------------------------------------------------------------------------
proc ::matrix::SetElem { mat row col val } {

  upvar $mat matrix

  lset matrix $row $col $val

  return $matrix

}

# ------------------------------------------------------------------------------
proc ::matrix::GetRow { matrix row } {

  return [lindex $matrix $row]

}

# ------------------------------------------------------------------------------
proc ::matrix::SetRow { matrix row newvalues {imin 0} {imax ""} } {

  upvar $matrix mat

  if {$imax == ""} then {
    foreach {nrows ncols} [Shape $mat] {break}
    if {$ncols == ""} then {
      # the matrix is a vector
      set imax 0
    } else {
      set imax [expr {$ncols - 1}]
    }
  }
  set icol $imin
  foreach value $newvalues {
    lset mat $row $icol $value
    incr icol
    if {$icol > $imax} then {
      break
    }
  }
  return $mat

}

# ------------------------------------------------------------------------------
proc ::matrix::GetCol { matrix col {imin 0} {imax ""} } {

  if {$imax == ""} then {
    set nrows [llength $matrix]
    set imax [expr {$nrows - 1}]
  }
  set result {}
  set iline 0
  foreach row $matrix {
    if {$iline>=$imin && $iline<=$imax} then {
      lappend result [lindex $row $col]
    }
    incr iline
  }

  return $result

}

# ------------------------------------------------------------------------------
proc ::matrix::SetCol { matrix col newvalues  {imin 0} {imax ""} } {

  upvar $matrix mat

  if {$imax == ""} then {
    set nrows [llength $mat]
    set imax [expr {$nrows - 1}]
  }
  set index 0
  for { set i $imin } { $i <= $imax } { incr i } {
    lset mat $i $col [lindex $newvalues $index]
    incr index
  }

  return $mat

}

# ------------------------------------------------------------------------------
# Destructive operations on a matrix

# ------------------------------------------------------------------------------
proc ::matrix::CHS { mat } {

  set new {}
  foreach row $mat {
    set nrow {}
    foreach col $row {
      if {[string index $col 0] == "-"} {
        lappend nrow [string range "$col" 1 end]
      } else {
        lappend nrow "-$col"
      }
    }
    lappend new $nrow
  }

  return $new

}

# ------------------------------------------------------------------------------
proc ::matrix::Transpose { mat } {

  set new {}
  set cc 0
  foreach col [lindex $mat 0] {
    set nrow {}
    foreach row $mat {
      lappend nrow [lindex $row $cc]
    }
    lappend new $nrow
    incr cc
 }

 return $new

}

# ------------------------------------------------------------------------------
proc ::matrix::SwapRows { matrix irow1 irow2 {imin 0} {imax ""}} {

  upvar $matrix mat

  if {$imax == ""} then {
    foreach {nrows ncols} [Shape $mat] {break}
    if {$ncols==""} then {
      # the matrix is a vector
      set imax 0
    } else {
      set imax [expr {$ncols - 1}]
    }
  }
  set row1 [lrange [lindex $mat $irow1] $imin $imax]
  set row2 [lrange [lindex $mat $irow2] $imin $imax]
  SetRow mat $irow1 $row2 $imin $imax
  SetRow mat $irow2 $row1 $imin $imax

  return $mat

}

# ------------------------------------------------------------------------------
# Operations with two matrices

# ------------------------------------------------------------------------------
proc ::matrix::Add { mat1 mat2 } {

  variable OVERFLOW

  set new {}
  foreach row1 $mat1 row2 $mat2 {
    set nrow {}
    foreach elm1 $row1 elm2 $row2 {
      set nv [expr {$elm1 + $elm2}]
      if {[::s56b::Limit nv]} { set OVERFLOW 1 }
      lappend nrow $nv
    }
    lappend new $nrow
  }

  return $new

}

# ------------------------------------------------------------------------------
proc ::matrix::Sub { mat1 mat2 } {

  variable OVERFLOW

  set new {}
  foreach row1 $mat1 row2 $mat2 {
    set nrow {}
    foreach elm1 $row1 elm2 $row2 {
      set nv [expr {$elm1 - $elm2}]
      if {[::s56b::Limit nv]} { set OVERFLOW 1 }
      lappend nrow $nv
    }
    lappend new $nrow
  }

  return $new

}

# ------------------------------------------------------------------------------
proc ::matrix::Multiply { mat1 mat2 } {

  variable OVERFLOW

  set new {}
  set tmat [Transpose $mat2]
  foreach row1 $mat1 {
    set nrow {}
    foreach row2 $tmat {
      set nv [DotProduct $row1 $row2]
      if {[::s56b::Limit nv]} { set OVERFLOW 1 }
      lappend nrow $nv

    }
    lappend new $nrow
  }

  return $new

}

# ------------------------------------------------------------------------------
proc ::matrix::matmul { mv1 mv2 } {

  switch "[MorV $mv1][MorV $mv2]" {
    "MM" {
       return [Multiply $mv1 $mv2]
    }
    "MC" {
       return [matmul_mv $mv1 $mv2]
    }
    "RM" {
       return [matmul_vm [Transpose $mv1] $mv2]
    }
    "RC" {
       return [DotProduct [Transpose $mv1] $mv2]
    }
    "CM" {
       return [DotProduct [matmul_vm $mv1 $mv2]]
    }
    "CR" {
       return [matmul_vv $mv1 [Transpose $mv2]]
    }
    "CC" {
       return [matmul_vv $mv1 $mv2]
    }
    "SS" {
      return [expr {$mv1 * $mv2}]
    }
    default {
      error "" "" {DIMMAT}
    }
  }

}

# ------------------------------------------------------------------------------
proc ::matrix::matmul_mv { matrix vector } {

  set newvect {}
  foreach row $matrix {
    set sum 0.0
    foreach v $vector c $row {
      set sum [expr {$sum+$v*$c}]
    }
    lappend newvect $sum
  }

  return $newvect

}

# ------------------------------------------------------------------------------
proc ::matrix::matmul_vm { vector matrix } {

  return [Transpose [matmul_mv [Transpose $matrix] $vector]]

}

# ------------------------------------------------------------------------------
proc ::matrix::matmul_vv { vect1 vect2 } {

  set newmat {}
  foreach v1 $vect1 {
    set newrow {}
    foreach v2 $vect2 {
      lappend newrow [expr {$v1*$v2}]
    }
    lappend newmat $newrow
  }

  return $newmat

}

# ------------------------------------------------------------------------------
proc ::matrix::axpy { scale mat1 mat2 } {

  variable OVERFLOW

  set new {}
  foreach row1 $mat1 row2 $mat2 {
    set nrow {}
    foreach elm1 $row1 elm2 $row2 {
      set nv [expr {$scale*$elm1+$elm2}]
      if {[::s56b::Limit nv]} { set OVERFLOW 1 }
      lappend nrow $nv
    }
    lappend new $nrow
  }

  return $new

}

# ------------------------------------------------------------------------------
proc ::matrix::DotProduct { vect1 vect2 } {

  variable OVERFLOW

  set sum 0.0
  foreach elm1 $vect1 elm2 $vect2 {
    set sum [expr {$sum + ($elm1 * $elm2)}]
  }

  return $sum

}

# ------------------------------------------------------------------------------
proc ::matrix::MatOpScalar { mat scalar op } {

  variable OVERFLOW

  set new {}
  foreach row $mat {
    set nrow {}
    foreach elm $row {
      set nv [expr $elm $op (1.0*$scalar)]
      if {[::s56b::Limit nv]} { set OVERFLOW 1 }
      lappend nrow $nv
    }
    lappend new $nrow
  }

  return $new

}

# ------------------------------------------------------------------------------
proc ::matrix::ScalarOpMat { scalar mat op } {

  variable OVERFLOW

  set new {}
  foreach row $mat {
    set nrow {}
    foreach elm $row {
      set nv [expr $scalar $op (1.0*$elm)]
      if {[::s56b::Limit nv]} { set OVERFLOW 1 }
      lappend nrow $nv
    }
    lappend new $nrow
  }

  return $new

}

# ------------------------------------------------------------------------------
# Solving linear equations

# ------------------------------------------------------------------------------
proc ::matrix::solvePGauss { matrix bvect {ipiv {}} } {

  if {[llength $ipiv] == 0} {
    set ipiv [dgetrf matrix]
  }
  set norows [llength $matrix]
  set nm1 [expr {$norows - 1}]

  # Perform all permutations on b
  for { set k 0 } { $k < $nm1 } { incr k } {
    # Swap b(k) and b(mu) with mu = P(k)
    set tmp [lindex $bvect $k]
    set mu [lindex $ipiv $k]
    SetRow bvect $k [lindex $bvect $mu]
    SetRow bvect $mu $tmp
  }

  # Perform forward substitution
  for { set k 0 } { $k < $nm1 } { incr k } {
    set bk [lindex $bvect $k]
    # Substitution
    for { set iline [expr {$k+1}] } { $iline < $norows } { incr iline } {
      set aik [lindex $matrix $iline $k]
      set maik [expr {-1. * $aik}]
      set bi [lindex $bvect $iline]
      SetRow bvect $iline [axpy $maik $bk $bi]
    }
  }

  # Perform backward substitution
  return [solveTriangular $matrix $bvect]

}

# ------------------------------------------------------------------------------
proc ::matrix::solveTriangular { matrix bvect {uplo "U"}} {

  set norows [llength $matrix]
  set nocols $norows

  switch $uplo {
    "U" {
      for { set i [expr {$norows-1}] } { $i >= 0 } { incr i -1 } {
        set sweep_row [GetRow $matrix $i]
        set bvect_sweep [GetRow $bvect $i]
        set sweep_fact [expr {double([lindex $sweep_row $i])}]
        if {$sweep_fact == 0.0} { set sweep_fact 1e-12 }
        set norm_fact [expr {1.0/$sweep_fact}]
        ::s56b::Limit norm_fact
        lset bvect $i [ScalarOpMat $norm_fact $bvect_sweep "*"]
        for { set j [expr {$i-1}] } { $j >= 0 } { incr j -1 } {
          set current_row [GetRow $matrix $j]
          set bvect_current [GetRow $bvect $j]
          set factor [expr {-[lindex $current_row $i]/$sweep_fact}]
          ::s56b::Limit factor
          lset bvect $j [axpy $factor $bvect_sweep $bvect_current]
        }
      }
    }
    "L" {
      for { set i 0 } { $i < $norows } { incr i } {
        set sweep_row [GetRow $matrix $i]
        set bvect_sweep [GetRow $bvect $i]
        set sweep_fact [expr {double([lindex $sweep_row $i])}]
        if {$sweep_fact == 0.0} { set sweep_fact 1e-12 }
        set norm_fact [expr {1.0/$sweep_fact}]
        ::s56b::Limit norm_fact
        lset bvect $i [ScalarOpMat $norm_fact $bvect_sweep "*"]
        for { set j 0 } { $j < $i } { incr j } {
        set bvect_current [GetRow $bvect $i]
          set bvect_sweep [GetRow $bvect $j]
          set factor [lindex $sweep_row $j]
          set factor [expr { -1.0 * $factor * $norm_fact }]
          lset bvect $i [axpy $factor $bvect_sweep $bvect_current]
        }
      }
    }
  }

  return $bvect

}

# ------------------------------------------------------------------------------
# HP-15C specific operations

# ------------------------------------------------------------------------------
proc ::matrix::ZP { mat } {

  set mre {}
  set mim {}
  foreach rr $mat {
    set row {}
    set irow {}
    foreach {elm1 elm2} $rr {
      lappend row $elm1
      lappend irow $elm2
    }
    lappend mre $row
    lappend mim $irow
  }

  return [concat $mre $mim]

}

# ------------------------------------------------------------------------------
proc ::matrix::ZC { mat } {

  set new {}
  set rh [expr [Rows $mat]/2]
  for {set rr 0} {$rr < $rh} {incr rr} {
    set nrow {}
    foreach elm1 [lindex $mat $rr] elm2 [lindex $mat [expr $rh+$rr]] {
      lappend nrow $elm1 $elm2
    }
    lappend new $nrow
  }

  return $new

}

# ------------------------------------------------------------------------------
proc ::matrix::ZPtoZtilde { mat } {

  set r2 [expr [Rows $mat]/2]
  set X [lrange $mat 0 $r2-1]
  set Y [lrange $mat $r2 end]

  set new {}
  foreach xrow $X yrow [CHS $Y] {
    lappend new [concat $xrow $yrow]
  }
  foreach yrow $Y xrow $X {
    lappend new [concat $yrow $xrow]
  }

  return $new

}

# ------------------------------------------------------------------------------
proc ::matrix::ZtildetoZP { mat } {

  set r2 [expr [Cols $mat]/2]
  set new {}
  foreach row $mat {
    lappend new [lrange $row 0 $r2-1]
  }

  return $new

}