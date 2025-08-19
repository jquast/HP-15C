# ------------------------------------------------------------------------------
#
#                        HTML Tag Attributes Package
#
#                          (c) 2021 Torsten Manz
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

package require Tcl 8.6-
package require html
package provide htmlTagAttr 1.1

namespace eval ::htmlTagAttr {

}

# ------------------------------------------------------------------------------
proc ::htmlTagAttr::img { imgtag imgdict } {

  upvar $imgdict this

  foreach key [list alt crossorigin height ismap loading longdesc referrerpolicy \
    sizes src srcset usemap width] {
    if {[::html::extractParam $imgtag $key pval]} {
      dict set this $key $pval
    } else {
      dict unset this $key
    }
  }

}
