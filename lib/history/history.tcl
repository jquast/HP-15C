# ------------------------------------------------------------------------------
#
#                             history package
#
#                          (c) 2015 Torsten Manz
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
package provide history 1.0.2

namespace eval ::history {

}

# ------------------------------------------------------------------------------
proc ::history::create { maxentries } {

  return [dict create maxEntries $maxentries entries {}]

}

# ------------------------------------------------------------------------------
proc ::history::size { hist {nsize -1} } {

  upvar $hist this

  if {$nsize >= 0} {
    if {$nsize < [llength [dict get $this entries]]} {
      dict set this entries [lreplace [dict get $this entries] $nsize end]
    }
    dict set this maxEntries $nsize
  }

  return [dict get $this maxEntries]

}

# ------------------------------------------------------------------------------
proc ::history::add { hist newentry } {

  upvar $hist this

  set idx [lsearch -exact [dict get $this entries] $newentry]
  if {$idx == 0} { ;# Value is first entry in history
    return
  } elseif {$idx < 0} { ;# Value is not in history
    set rr [expr [llength [dict get $this entries]] >= [dict get $this maxEntries] ? 1 :0]
    set ohist [lrange [dict get $this entries] 0 end-$rr]
  } else { ;# Value is in history, move to first
    set ohist [lreplace [dict get $this entries] $idx $idx]
  }
  dict set this entries [linsert $ohist 0 $newentry]

}

# ------------------------------------------------------------------------------
proc ::history::del { hist delentry } {

  upvar $hist this

  set idx [lsearch [dict get $this entries] $delentry]
  if {$idx >= 0} { ;# Value is in history
    dict set this entries [lreplace [dict get $this entries] $idx $idx]
  }

}

# ------------------------------------------------------------------------------
proc ::history::get { hist {pos -1} } {

  upvar $hist this

  if {$pos < 0} {
    return [dict get $this entries]
  } elseif {$pos < [llength [dict get $this entries]]} {
    return [lindex [dict get $this entries] $pos]
  } else {
    return {}
  }

}

# ------------------------------------------------------------------------------
proc ::history::clear { hist } {

  upvar $hist this

  dict set this entries {}

}
