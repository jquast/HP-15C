# ------------------------------------------------------------------------------
#
#                    DM15 Package for the HP-15C Simulator
#
#                         (c) 2012-2024 Torsten Manz
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
# this program; if not, see <https://www.gnu.org/licenses/>
#
# ------------------------------------------------------------------------------

package require Tcl 8
package provide DM15 2.0.2

namespace eval ::DM15 {

  variable LogCmd ""

  variable REG0 "00000000000000"

  variable COM
  array set COM {
    id ""
    timeout 5
  }
  variable ReadBuffer ""

  variable MEM_TYPE ""
  variable MEM
  array set MEM {}

# Matrix row/col size is stored in register 19 and 1A. Start-byte is in reg 15.
# register | row-byte | col-byte | start-byte-in-reg-15
  set MATPOS {
    {M1 19 7 6 6}
    {M2 19 5 4 5}
    {M3 19 3 2 4}
    {M4 1A 7 6 3}
    {M5 1A 5 4 2}
  }

  variable SEQ_2_CODE {
    {([0-9]) f[0-9]}
    {10 fd}
    {11 ca}
    {12 cb}
    {13 cc}
    {14 cd}
    {15 ce}
    {16 c3}
    {20 fc}
    {22_([0-9]) 1[0-9]}
    {22_1([1-5]) 1[a-e]}
    {22_25 88}
    {22_48_([0-9]) ff1[0-9]}
    {23 c7}
    {24 c8}
    {25 c9}
    {26 c6}
    {21 ""}
    {22_16_([0-9]) ""}
    {30 fb}
    {31 c2}
    {32_([0-9]) 2[0-9]}
    {32_1([1-5]) 2[a-e]}
    {32_25 89}
    {32_48_([0-9]) ff2[0-9]}
    {33 c4}
    {34 c5}
    {35 ""}
    {36 c1}
    {40 fa}
    {41 ""}
    {48 c0}
    {49 fe}
    {42_0 d0}
    {42_1 d1}
    {42_2 d2}
    {42_3 d3}
    {42_4_0 80}
    {42_4_1 90}
    {42_4_([2-9]) ef5[2-9]}
    {42_4_1([1-5]) ef5[a-e]}
    {42_4_24 81}
    {42_4_25 91}
    {42_4_48_([0-9]) ef6[0-9]}
    {42_5_0 82}
    {42_5_1 92}
    {42_5_([2-9]) ef7[2-9]}
    {42_5_1([1-5]) ef7[a-e]}
    {42_5_24 83}
    {42_5_25 93}
    {42_5_48_([0-9]) ef8[0-9]}
    {42_6_0 84}
    {42_6_1 94}
    {42_6_([2-9]) ef9[2-9]}
    {42_6_1([1-5]) ef9[a-e]}
    {42_6_24 85}
    {42_6_25 95}
    {42_6_48_([0-9]) efa[0-9]}
    {42_7_([0-9]) ff6[0-9]}
    {42_7_25 ff6e}
    {42_8_([0-9]) ff7[0-9]}
    {42_8_25 ff7e}
    {42_9_([0-9]) ff8[0-9]}
    {42_9_25 ff8e}
    {42_10_([0-9]) ef1[0-9]}
    {42_10_1([1-5]) ef1[a-e]}
    {42_10_48_([0-9]) ef2[0-9]}
    {42_16_([0-9]) ff9[0-9]}
    {42_20_([0-9]) ef3[0-9]}
    {42_20_1([1-5]) ef3[a-e]}
    {42_20_48_([0-9]) ef4[0-9]}
    {42_21_([0-9]) 0[0-9]}
    {42_21_1([1-5]) 0[a-e]}
    {42_21_48_([0-9]) ff0[0-9]}
    {42_22_23 d4}
    {42_22_24 d5}
    {42_22_25 d6}
    {42_23_1([1-5]) 9[a-e]}
    {42_23_24 98}
    {42_23_25 99}
    {42_24 ""}
    {42_25 a4}
    {42_26_1([1-5]) 8[a-e]}
    {42_30 db}
    {42_31 dc}
    {42_32 dd}
    {42_33 ""}
    {42_34 a5}
    {42_35 ""}
    {42_36 a1}
    {42_40 da}
    {42_44 a3}
    {42_45 ""}
    {42_48 a0}
    {42_49 de}
    {43_0 e0}
    {43_1 e1}
    {43_2 e2}
    {43_3 e3}
    {43_4_([0-9]) ff3[0-9]}
    {43_4_25 ff3e}
    {43_5_([0-9]) ff4[0-9]}
    {43_5_25 ff4e}
    {43_6_([0-9]) ff5[0-9]}
    {43_6_25 ff5e}
    {43_7 e7}
    {43_8 e8}
    {43_9 e9}
    {43_10 ed}
    {43_11 ba}
    {43_12 bb}
    {43_13 bc}
    {43_14 bd}
    {43_15 be}
    {43_16 b3}
    {43_20 ec}
    {43_21 ""}
    {43_22_23 e4}
    {43_22_24 e5}
    {43_22_25 e6}
    {43_23 b7}
    {43_24 b8}
    {43_25 b9}
    {43_26 b6}
    {43_30_([0-9]) 7[0-9]}
    {43_31 ""}
    {43_32 b2}
    {43_33 b4}
    {43_34 b5}
    {43_35 a2}
    {43_36 b1}
    {43_40 ea}
    {43_44 eb}
    {43_45 ""}
    {43_48 b0}
    {43_49 ee}
    {44_([0-9]) 4[0-9]}
    {44_10_([0-9]) dfe[0-9]}
    {44_10_1([1-5]) dfe[a-e]}
    {44_10_24 dffd}
    {44_10_25 dffe}
    {44_10_48_([0-9]) dff[0-9]}
    {44_1([1-5]) 4[a-e]}
    {44_1([1-5])_u bf4[a-e]}
    {44_16_1([1-5]) ffa[a-e]}
    {44_20_([0-9]) dfc[0-9]}
    {44_20_1([1-5]) dfc[a-e]}
    {44_20_24 dfdd}
    {44_20_25 dfde}
    {44_20_48_([0-9]) dfd[0-9]}
    {44_24 96}
    {44_24_u bf96}
    {44_25 97}
    {44_26 a6}
    {44_30_([0-9]) dfa[0-9]}
    {44_30_1([1-5]) dfa[a-e]}
    {44_30_24 dfbd}
    {44_30_25 dfbe}
    {44_30_48_([0-9]) dfb[0-9]}
    {44_36 d9}
    {44_42_36 d9}
    {44_40_([0-9]) df8[0-9]}
    {44_40_1([1-5]) df8[a-e]}
    {44_40_24 df9d}
    {44_40_25 df9e}
    {44_40_48_([0-9]) df9[0-9]}
    {44_43_1([1-5]) 6[a-e]}
    {44_43_24 af6d}
    {44_48_([0-9]) 6[0-9]}
    {45_([0-9]) 3[0-9]}
    {45_10_([0-9]) cfe[0-9]}
    {45_10_1([1-5]) cfe[a-e]}
    {45_10_24 cffd}
    {45_10_25 cffe}
    {45_10_48_([0-9]) cff[0-9]}
    {45_1([1-5]) 3[a-e]}
    {45_1([1-5])_u bf3[a-e]}
    {45_16_1([1-5]) 7[a-e]}
    {45_20_([0-9]) cfc[0-9]}
    {45_20_1([1-5]) cfc[a-e]}
    {45_20_24 cfdd}
    {45_20_25 cfde}
    {45_20_48_([0-9]) cfd[0-9]}
    {45_23_1([1-5]) a[a-e]}
    {45_23_24 a8}
    {45_23_25 a9}
    {45_24 86}
    {45_24_u bf86}
    {45_25 87}
    {45_26 d7}
    {45_30_([0-9]) cfa[0-9]}
    {45_30_1([1-5]) cfa[a-e]}
    {45_30_24 cfbd}
    {45_30_25 cfbe}
    {45_30_48_([0-9]) cfb[0-9]}
    {45_36 d8}
    {45_40_([0-9]) cf8[0-9]}
    {45_40_1([1-5]) cf8[a-e]}
    {45_40_24 cf9d}
    {45_40_25 cf9e}
    {45_40_48_([0-9]) cf9[0-9]}
    {45_43_1([1-5]) 5[a-e]}
    {45_43_24 af5d}
    {45_48_([0-9]) 5[0-9]}
    {45_49 a7}
  }

}

# ------------------------------------------------------------------------------
# Memory section

# ------------------------------------------------------------------------------
proc ::DM15::LookupCode { cc } {

  variable SEQ_2_CODE

  set rc ""
  foreach ff $SEQ_2_CODE {
    if {[regexp -nocase "^[lindex $ff 1]\$" $cc]} {
      set rc [lindex $ff 0]
      break
    }
  }

  if {$rc eq ""} { error "[mc dm15cc.err.unknowncode $cc]" }

  return $rc

}

# ------------------------------------------------------------------------------
proc ::DM15::LookupSeq { cc } {

  variable SEQ_2_CODE

  set rc ""
  foreach ff $SEQ_2_CODE {
    if {[regexp -nocase "^[lindex $ff 0]\$" $cc]} {
      set rc [lindex $ff 1]
      break
    }
  }

  return $rc

}

# ------------------------------------------------------------------------------
proc ::DM15::BCD { var } {

  variable REG0

  if {$var == 0.0} {
    return $REG0
  }

  set str [format "%+1.9e" $var]
  set sign [expr $var < 0 ? 9 : 0]
  set esign [expr log(abs($var)) < 0 ? 9 : 0]
  set mantissa [string map {"." ""} [string range $str 1 11]]
  if {"$esign" eq "0"} {
    set exp [format "%02.0f" [string range $str 15 16].]
  } else {
    set exp [format "%02.0f" [expr 100-[string range $str 15 16].]]
  }

  return "$sign$mantissa$esign$exp"

}

# ------------------------------------------------------------------------------
proc ::DM15::BCDToFloat { bcd } {

  variable REG0

  if {$bcd == $REG0} {
    return 0.0
  }

  if {[string index $bcd 0] eq "0"} {
    set sign "+"
  } else {
    set sign "-"
  }
  set mantissa \
    [format "%+1.12f" "$sign[string range $bcd 1 1].[string range $bcd 2 10]"]
# If BCD is an element of a matrix in LU-form, the exponent sign is NOT 0 (+) or
# 9 (-) but 1 or 8.
  if {[expr 0x[string index $bcd 11]] < 8} {
    set exp [format "+%02.0f" [string range $bcd 12 13].]
  } else {
    set exp [format "-%02.0f" [expr 100-[string range $bcd 12 13].]]
  }

  return "$mantissa\e$exp"

}

# ------------------------------------------------------------------------------
proc ::DM15::EncodeReg { val } {

  if {[string index $val 0] eq "M"} {
    set rc [format "1%c000000000000" [expr 96+[string index $val 1]]]
  } else  {
    set rc [BCD $val]
  }

  return $rc

}

# ------------------------------------------------------------------------------
proc ::DM15::DecodeReg { reg } {

# Sign nybble is "1" when content is a matrix descriptor
  if {[string index $reg 0] eq "1"} {
    set rc "M[expr 0x[string index $reg 1] - 9]"
  } else  {
    set rc [BCDToFloat $reg]
  }

  return $rc

}

# ------------------------------------------------------------------------------
proc ::DM15::SetByte { reg byte val } {

  variable MEM

  set offs [expr 14 - 2*$byte]
  set MEM([expr 0x$reg]) [string replace $MEM([expr 0x$reg]) $offs $offs+1 $val]

}

# ------------------------------------------------------------------------------
proc ::DM15::GetByte { reg byte } {

  variable MEM

# Each register is 14 nibbles long, bytes run from right to left from 1 to 7
  set offs [expr 14 - 2*$byte]
  return [string range $MEM([expr 0x$reg]) $offs $offs+1]

}


# ------------------------------------------------------------------------------
proc ::DM15::FillRow { reg0 } {

  variable REG0
  variable MEM

# Get first reg in row
  set reg0 [expr int($reg0/4)*4]
  for {set rr $reg0} {$rr < $reg0+4} {incr rr} {
    if {![info exists MEM($rr)]} {
      set MEM($rr) $REG0
    }
  }

}

# ------------------------------------------------------------------------------
proc ::DM15::MemInfo {} {

  variable MEM_TYPE

  set rc [dict create firmware $MEM_TYPE]
  set da [expr "0x[GetByte 15 7]"]
  if {$da < [expr 0x80]} {
    dict set rc totregs 229
  } elseif {$da < [expr 0xc0]} {
    dict set rc totregs 128
  } else {
    dict set rc totregs 64
  }

  dict set rc poolregs [expr 256 - 0x[GetByte 15 1]]
  dict set rc dataregs [expr max(0x[GetByte 15 6]-0x[GetByte 15 7]+1, 0)]
  dict set rc matregs [expr 0x[GetByte 15 1]-0x[GetByte 15 6]]
  if {[GetByte 16 1] eq "00"} {
    dict set rc prgmregs 0
  } else {
    dict set rc prgmregs [expr 256 - 0x[GetByte 16 1]]
  }

  return $rc

}

# ------------------------------------------------------------------------------
proc ::DM15::SetFlags { flags } {

  variable MEM
  upvar $flags farr

  if {![info exists MEM([expr 0x1A])]} {
    error "[mc dm15cc.err.meminit]"
  }

# Guarantee full row of 4 register
  FillRow 24

  set fres 0
  for {set ff 0} {$ff < 8} {incr ff} {
    incr fres [expr $farr($ff)*2**$ff]
  }
  SetByte 1A 2 [format "%02x" $fres]

}

# ------------------------------------------------------------------------------
proc ::DM15::GetFlags { flags } {

  variable MEM
  upvar $flags farr

  if {![info exists MEM([expr 0x1A])]} {
    error "[mc dm15cc.err.meminit]"
  }

  set fset [expr 0x[GetByte 1A 2]]
  for {set ff 0} {$ff < 8} {incr ff} {
    set farr($ff) [expr ($fset & 2**$ff) > 0]
  }

}

# ------------------------------------------------------------------------------
proc ::DM15::SetStack { stack istack } {

  variable REG0
  variable MEM
  upvar $stack starr
  upvar $istack istarr

  if {![info exists MEM([expr 0x0A])]} {
    error "[mc dm15cc.err.meminit]"
  }

  foreach {stl reg} {x -78 y 0 z 1 t 2 LSTx 19} {
    set MEM($reg) [EncodeReg $starr($stl)]
  }
  if {![info exists MEM(3)]} {
    set MEM(3) $REG0
  }

# Guarantee full row of 4 registers, starting with 0x10
  FillRow 16

# Set complex stack if complex mode is on in DM15
  if {[expr 0x[GetByte 0A 5] & 1]} {
    set r0 [expr 0x[GetByte 15 7] - 5]
    foreach reg {LSTx t z y x} {
      set MEM($r0) [BCD $istarr($reg)]
      incr r0
    }
# Guarantee full row of 4 registers, starting at ix register
    FillRow [expr 0x[GetByte 15 7]-1]
  }

}

# ------------------------------------------------------------------------------
proc ::DM15::GetStack { stack {istack ""} } {

  variable MEM
  upvar $stack starr

# x register has to be there
  if {![info exists MEM(-78)]} {
    error "[mc dm15cc.err.meminit]"
  }

  foreach {stl reg} {x -78 y 0 z 1 t 2 LSTx 19} {
# y, z and t register are only transfered if they are not zero
    if {[info exists MEM($reg)]} {
      set starr($stl) [DecodeReg $MEM($reg)]
    }
  }

  if {$istack != ""} {
    upvar $istack istarr
    set r0 [expr 0x[GetByte 15 7] - 5]
    foreach reg {LSTx t z y x} {
      if {[catch {set istarr($reg) [DM15::BCDToFloat $MEM($r0)]}]} {
        set istarr($reg) 0.0
      }
      incr r0
    }
  }

}

# ------------------------------------------------------------------------------
proc ::DM15::SetStorage { storage } {

  variable REG0
  variable MEM
  upvar $storage stoarr

  if {![info exists MEM([expr 0x15])]} {
    error "[mc dm15cc.err.meminit]"
  }

# Get Base ADdRess of data regs, # of variable storage regs and available regs
  set badr [expr 0x[GetByte 15 7]]
# Do not count the 'fixed' registers R0, R1, R2 and RI
  set rmax [expr [array size stoarr]-4]
  set rdef [expr 0x[GetByte 15 1] - 0x[GetByte 15 7]]
  if {$rmax > $rdef} {
    error "[mc dm15cc.storagecnt]"
  }

  set MEM([expr 0x10]) [EncodeReg $stoarr(0)]
  set MEM([expr 0x11]) [EncodeReg $stoarr(1)]
  set MEM([expr 0x12]) [EncodeReg $stoarr(I)]
  if {![info exists MEM([expr 0x13])]} {
    set MEM([expr 0x13]) $REG0
  }
  for {set reg 2} {$reg <= $rmax+2} {incr reg} {
    if {[info exists stoarr($reg)]} {
      set MEM([expr $badr+$reg-2]) [EncodeReg $stoarr($reg)]
    }
  }
  FillRow $badr
  FillRow [expr $badr+$rmax]

}

# ------------------------------------------------------------------------------
proc ::DM15::GetStorage { storage } {

  variable MEM
  upvar $storage stoarr

# Get storage registers 0, 1 and I from fixed positions
  set reg [expr 0x10]
  foreach rr {0 1 I} {
    if {[info exists MEM($reg)]} {
      set stoarr($rr) [DecodeReg $MEM($reg)]
    }
    incr reg
  }

# Get storage registers 2 and higher
  set r2 [expr 0x[GetByte 15 7]]
  set rmax [expr 0x[GetByte 15 6]]
  for {set rr $r2} {$rr < $rmax} {incr rr} {
# storage registers are only transfered if they are not zero
    if {[info exists MEM($rr)]} {
      set stoarr([expr $rr-$r2+2]) [DecodeReg $MEM($rr)]
    } else {
      set stoarr([expr $rr-$r2+2]) 0.0
    }
  }

}

# ------------------------------------------------------------------------------
proc ::DM15::SetMatrices { matrices } {

  variable MEM
  upvar $matrices MAT
  variable MATPOS

  set reg [expr 0x[GetByte 15 6]]
  FillRow $reg
  foreach mm $MATPOS {
    lassign $mm md dreg row col pp
    SetByte $dreg $row [format "%02x" [::matrix::Rows $MAT($md)]]
    SetByte $dreg $col [format "%02x" [::matrix::Cols $MAT($md)]]
    SetByte 15 $pp [format "%02x" $reg]

    foreach elm [join $MAT($md)] {
      set MEM($reg) [BCD $elm]
      incr reg
    }

# For matrix in LU form, permutations are encoded in the diagonal elements
    if {[llength $MAT($md\_LU)] > 0} {
      set nn [::matrix::Rows $MAT($md)]
      set rr [expr 0x[GetByte 15 $pp]]
      for {set ii 0} {$ii < [llength $MAT($md\_LU)]} {incr ii} {
# Set last three bits of exponent sign nybbles to permutation index
        set sign [expr ([string index $MEM($rr) 11] & 8) | [lindex $MAT($md\_LU) $ii]]
        set MEM($rr) [string replace $MEM($rr) 11 11 [format "%x" $sign]]
        incr rr [expr $nn + 1]
      }
# Permutation index of last diagonal element is always (n-1)
      set sign [expr ([string index $MEM($rr) 11] & 8) | ($nn-1)]
      set MEM($rr) [string replace $MEM($rr) 11 11 [format "%x" $sign]]
    }
  }
  FillRow $reg

# Set address of first pool register after last matrix element
  SetByte 15 1 [format "%02x" $reg]

}

# ------------------------------------------------------------------------------
proc ::DM15::GetMatrices { matrices } {

  variable MEM
  variable MATPOS
  upvar $matrices matarr
  array unset matarr
  set rc {}

  foreach mm $MATPOS {
    lassign $mm md dreg row col pp
    set rr [expr 0x[GetByte $dreg $row]]
    set cc [expr 0x[GetByte $dreg $col]]
    set reg0 [expr 0x[GetByte 15 $pp]]

    set nmat {}
    set matarr($md\_LU) {}
    for {set ii 0} {$ii < $rr} {incr ii} {
      set nrow {}
      for {set jj 0} {$jj < $cc} {incr jj} {
        set elm 0.0
        set reg [expr $reg0+($ii*$cc)+$jj]
        if {[info exists MEM($reg)]} {
          set elm [BCDToFloat $MEM($reg)]
# Check if matrix is in LU form = diagonal elements
          set perm [expr 7 & 0x[string index $MEM($reg) 11]]
          if {$ii == $jj && $perm > 0} {
            lappend matarr($md\_LU) $perm 
          }
        }
        lappend nrow $elm
      }
      lappend nmat $nrow
    }
    set matarr($md) $nmat
    
  }

}

# ------------------------------------------------------------------------------
proc ::DM15::SetResultMatrix { mat } {

  variable MEM

  if {![info exists MEM([expr 0x1A])]} {
    error "[mc dm15cc.err.meminit]"
  }

  SetByte 1A 3 [string tolower $mat][string index [GetByte 1A 3] 1]

}

# ------------------------------------------------------------------------------
proc ::DM15::GetResultMatrix { } {

  variable MEM

  if {![info exists MEM([expr 0x1A])]} {
    error "[mc dm15cc.err.meminit]"
  }

  return [string toupper [string index [GetByte 1A 3] 0]]


}

# ------------------------------------------------------------------------------
proc ::DM15::SetPrgm { PRGM } {

  variable MEM
  upvar $PRGM prgm

  if {![info exists MEM([expr 0x15])] || ![info exists MEM([expr 0x16])]} {
    error "[mc dm15cc.err.meminit]"
  }

# Clear all program regs
  set dmax [expr 0x[GetByte 15 1]]
  for {set rr $dmax} {$rr < 256} {incr rr} {
    array unset MEM $rr
  }
# Ensure full row of 4 registers at the end of the data regs
  FillRow [expr $dmax-1]

# Map program to a code string with first line at the end
  set pl ""
  set i0 [expr [llength $prgm]-1]
  for {set ii $i0} {$ii > 0} {incr ii -1} {
    set step [lindex $prgm $ii]
    set cc [LookupSeq $step]
    if {[string first {[0-9]} $cc] > 0 || [string first {[2-9]} $cc] > 0} {
      regsub {\[.*\]} $cc [string index $step end] cc
    } else {
      regsub "_u$" $step "" step
      regsub {\[.*\]} $cc [format "%c" [expr 96+[string index $step end]]] cc
    }

    if {[string length $cc] > 2} {
      append pl [string range $cc 2 3] [string range $cc 0 1]
    } else {
      append pl $cc
    }
  }

# Check if program fits into pool registers
  if {[string length $pl]/14 > [expr 256 - 0x[GetByte 15 1]]} {
    error "[mc prgm.tolarge]"
  }

# Split code string into registers
  set reg [expr 0xFF]
  set idx0 [expr [string length $pl]-14]
  for {set idx $idx0} {$idx > -14} {incr idx -14} {
    set MEM($reg) [format "%014s" [string range $pl $idx $idx+13]]
    incr reg -1
  }

# Set end of program as <# of bytes><in last register>
  set plen [string length $pl]
  if {$plen == 0} {
    set lreg 0
  } else {
    set lreg [expr 256 - int(ceil($plen / 14.0))]
# Ensure full row of 4 registers at the bottom of the program regs
    FillRow $lreg
  }

  if {$plen % 14 == 0 && $plen > 0} {
    SetByte 16 2 07
  } else {
    SetByte 16 2 [format "%02x" [expr ($plen % 14)/2]]
  }
  SetByte 16 1 [format "%02x" $lreg]

}

# ------------------------------------------------------------------------------
proc ::DM15::GetPrgm {} {

  variable MEM

  if {![info exists MEM([expr 0x16])]} {
    error "[mc dm15cc.err.meminit]"
  }

  set rc { {} }
  set prgm ""
  set preg0 [expr 0x[GetByte 16 1]]
# If no program is in memory, the 'last' register is 00
  if {$preg0 == 0} {return $rc}

  for {set reg $preg0} {$reg < 256} {incr reg} {
    append prgm $MEM($reg)
  }
  set prgm [string range $prgm [expr 14 - 2*0x[GetByte 16 2]] end]

  for {set ii [expr [string length $prgm]-2]} {$ii >= 0} {incr ii -2} {
    set cc [string range $prgm $ii [expr $ii+1]]
    if {[string index $cc 1] eq "f"} {
      incr ii -2
      append cc [string range $prgm $ii [expr $ii+1]]
    }
    set seq [LookupCode $cc]
    if {[string first {([0-9])} $seq] > -1 || [string first {[2-9]} $seq] > -1} {
      regsub {\(\[.*\]\)} $seq [string index $cc end] seq
    } elseif {[string first {([1-5])} $seq] > 0} {
      regsub {\(\[.*\]\)} $seq [expr [scan [string index $cc end] "%c"]-96] seq
    }
    lappend rc $seq
  }

  return $rc

}

# ------------------------------------------------------------------------------
# Communication section

# ------------------------------------------------------------------------------
proc ::DM15::Log { txt type } {

  variable LogCmd

  if {[info procs $LogCmd] != ""} {
    $LogCmd $txt $type
  }

}

# ------------------------------------------------------------------------------
proc ::DM15::DecodeMem { data } {

  variable MEM
  variable MEM_TYPE

  array unset MEM

# Detect firmware
  set MEM_TYPE ""
  regexp {(DM15(CC)*[^\n]*)} $data MEM_TYPE
  if {$MEM_TYPE eq ""} {
    error "[mc dm15cc.fw.notidentified]"
  }

  foreach ll [split $data "\n"] {
    regsub -all " +" [string trim $ll] " " ll
    if {[regexp {(^[0-9a-f][0-9a-f]) (.*)} $ll ign adr dat]} {
      set reg [expr 0x$adr]
      foreach rr [split $dat " "] {
        set MEM($reg) $rr
        incr reg
      }
    } elseif {[regexp {^[A-Z]: .*} $ll ign]} {
      foreach {reg val} [split $ll " "] {
        set MEM(-[scan $reg "%c"]) $val
      }
    }
  }

# If reg 0x15 or 0x16 is not set, no data has been read in
  if {![info exists MEM([expr 0x15])] || ![info exists MEM([expr 0x16])]} {
    set MEM_TYPE ""
    error "[mc dm15cc.err.read]"
  }

}

# ------------------------------------------------------------------------------
proc ::DM15::EncodeMem {} {

  variable MEM_TYPE
  variable MEM

  set rc "$MEM_TYPE"

  if {![info exists MEM([expr 0x15])]} {
    error "[mc dm15cc.err.meminit]"
  }

# Encode registers 00-1F
  for {set reg 0} {$reg < 256} {incr reg} {
    if {[info exists MEM($reg)]} {
      if {$reg % 4 == 0} {
        append rc "\n[format "%02x" $reg]"
      }
      append rc "  " $MEM($reg)
    }
  }

# Encode registers A, B, C, M, N and G
  append rc "\n"
  foreach reg {-65 -66 -67 -83 -77 -78 -71} {
    if {[info exists MEM($reg)]} {
      append rc "[format "%c:" [expr abs($reg)]] $MEM($reg)"
      if {$reg in {-67 -83}} {
        append rc "\n"
      } elseif {$reg != "-71"} {
        append rc "  "
      }
    } else {
      error "[mc dm15cc.err.meminit]"
    }

  }

  return $rc

}

# ------------------------------------------------------------------------------
proc ::DM15::comport { port } {

  variable COM

  if {$::tcl_platform(os) eq "Darwin"} {
    if {$COM(spdriver) eq "slabs"} {
      return "/dev/cu.SLAB_USBtoUART"
    } else {
      return "/dev/cu.usbserial-[format {%04d} $port]"
    }
  } elseif {$::tcl_platform(platform) eq "unix"} {
    return "/dev/ttyUSB$port"
  } else {
    return "\\\\.\\com$port"
  }

}

# ------------------------------------------------------------------------------
proc ::DM15::Open { port } {

  variable COM

  if {$COM(id) != ""} { return }

  set COM(WaitTimeout) 0
  set device [comport $port]
  if {[catch {open $device RDWR} fid options]} {
    ::DM15::Log "$::errorCode - $::errorInfo" error
    error "[mc dm15cc.err.open $port]"
  } else {
    set COM(id) $fid
# On some Linux systems /dev/ttyUSB# might not be recognized as a serial device
    if {[catch {fconfigure $COM(id) -mode 38400,n,8,1}]} {
      ::DM15::Close
      error "[mc dm15cc.err.noserialdev $device]"
    }
    fconfigure $COM(id) -blocking 0 -buffering none -translation {crlf cr}
  }

}

# ------------------------------------------------------------------------------
proc ::DM15::Close {} {

  variable COM

  catch {
    fileevent $COM(id) readable {}
# Clear pending transmisions from the device.
    catch {read $COM(id)}
    close $COM(id)
  }
  set COM(WaitTimeout) 0
  set COM(id) ""

}

# ------------------------------------------------------------------------------
proc ::DM15::Send { data } {

  variable COM

  foreach ll [split $data "\n"] {
    puts -nonewline $COM(id) "$ll\n"
  }
  flush $COM(id)
  ::DM15::Log $data info

}

# ------------------------------------------------------------------------------
proc ::DM15::ReadCB { endtag } {

  variable ReadBuffer
  variable COM

  set din ""
  catch {set din [read $COM(id)]}
  ::DM15::Log $din warning
  append ReadBuffer $din
  if {[regexp $endtag $din]} {
    set COM(ReadComplete) 1
  } elseif {[string first "Bye" $din ] > -1} {
    set COM(ReadComplete) 1
    ::DM15::Close
  }

}

# ------------------------------------------------------------------------------
proc ::DM15::WaitTimeout {} {

  variable COM

  set COM(WaitTimeout) 1
  set COM(ReadComplete) 1

}

# ------------------------------------------------------------------------------
proc ::DM15::Wait {} {

  variable COM

  set afterId [after [expr $COM(timeout)*1000] ::DM15::WaitTimeout]
  vwait ::DM15::COM(ReadComplete)
  catch {after cancel $afterId}
  if {$COM(WaitTimeout) == 1} {
    error "[mc dm15cc.err.timeout]"
  }

}

# ------------------------------------------------------------------------------
proc ::DM15::ReadStatus {} {

  variable ReadBuffer ""
  variable COM
  set DM15status [dict create]

# Get firmware
  fileevent $COM(id) readable [list ::DM15::ReadCB "VOYAGER >>"]
  Send "?"
  Wait
  set rb [split $ReadBuffer "\n"]
  if {[regexp {.*(DM15_?.*)_(.*)} [lindex $rb 1] ign fwtype fwversion]} {
    dict set DM15status fwtype $fwtype
    dict set DM15status fwversion $fwversion
  }

# Get uptime
  if {[regexp {Uptime (.*)s} [lindex $rb end-1] ign uptime]} {
    dict set DM15status uptime $uptime
  }

# Get time
  set ReadBuffer ""
  fileevent $COM(id) readable [list ::DM15::ReadCB "VOYAGER >>"]
  Send "t"
  Wait
  catch {
    set dt [clock scan [lindex [split $ReadBuffer "\n"] 1] -locale en \
      -format {%Y-%m-%d %H:%M:%S %a}]
    dict set DM15status datetime $dt
  }

# Get battery voltage
  set ReadBuffer ""
  fileevent $COM(id) readable [list ::DM15::ReadCB "VOYAGER >>"]
  Send "b"
  Wait
  if {[regexp {BAT: (.*)mV} [lindex [split $ReadBuffer "\n"] 1] ign bvolt]} {
    dict set DM15status battery $bvolt
  }

  return $DM15status

}

# ------------------------------------------------------------------------------
proc ::DM15::ReadMem {} {

  variable ReadBuffer ""
  variable COM

  fileevent $COM(id) readable [list ::DM15::ReadCB "VOYAGER >>"]
  Send "s"
  Wait

  DecodeMem $ReadBuffer

}

# ------------------------------------------------------------------------------
proc ::DM15::WriteMem {} {

  variable ReadBuffer ""
  variable COM

  set data [EncodeMem]

  fileevent $COM(id) readable [list ::DM15::ReadCB "Waiting for data"]
  Send "l"
  Wait
  fileevent $COM(id) readable [list ::DM15::ReadCB "VOYAGER >>"]
  Send "$data"
  Wait

  if {[string first "Read OK" $ReadBuffer ] < 0} {
    error "[mc dm15cc.err.write]"
  }

}

# ------------------------------------------------------------------------------
proc ::DM15::WriteTime { {st -1} } {

  variable ReadBuffer ""
  variable COM

  if {$st == -1 } {
    set st [clock seconds]
  }

  fileevent $COM(id) readable [list ::DM15::ReadCB "VOYAGER >>"]
  Send "ts [clock format $st -format {%Y%m%d %H%M%S}]"
  Wait

}
