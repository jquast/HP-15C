# ------------------------------------------------------------------------------
#
#                   s56b Package for the HP-15C Simulator
#
#                          (c) 2016 Torsten Manz
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

package require Tcl 8-
package provide s56b 0.0.1

namespace eval ::s56b {

  variable REG0 "00000000000000"

  variable MAXVAL 9.999999999e99

}

# ------------------------------------------------------------------------------
proc ::s56b::Limit { reg } {

  upvar $reg uvar
  variable MAXVAL
  set rc 0
  set val $uvar

  if {$val == 0.0} { return $rc }

# Fixes weired formatting of infinite value on various operating systems
  if {$val in {Infinity 1.#INF} } {
    set val "Inf"
  } elseif {$val in {-Infinity -1.#INF} } {
    set val "-Inf"
  } else {
# Using the input directly would cause problems with octal input
    regsub {^(\-?)0+} $val {\1} val
  }

  if {abs($val) > 0.0 && abs($val) < 1E-99} {
    set uvar 0.0
  } elseif {[expr {$val > $MAXVAL}]} {
    set uvar $MAXVAL
    set rc 1
  } elseif {[expr {$val < -$MAXVAL}]} {
    set uvar -$MAXVAL
    set rc 1
  }

  return $rc

}

