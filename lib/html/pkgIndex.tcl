if {![package vsatisfies [package provide Tcl] 8.6-]} {return}
package ifneeded html 1.5 [list source [file join $dir html.tcl]]
package ifneeded htmlTagAttr 1.1 [list source [file join $dir htmlTagAttr.tcl]]
