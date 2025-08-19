if {![package vsatisfies [package provide Tcl] 8.5]} {return}
package ifneeded DM15 2.0.2 [list source [file join $dir DM15.tcl]]
