if {![package vsatisfies [package provide Tcl] 8.6-]} {return}
package ifneeded ncgi 1.4.4 [list source [file join $dir ncgi.tcl]]
