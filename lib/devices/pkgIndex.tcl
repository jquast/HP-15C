if {![package vsatisfies [package provide Tcl] 8.6-]} {return}
package ifneeded HP15MEM 1.0.01 [list source [file join $dir hp15mem.tcl]]
package ifneeded DEVIO 1.0.01 [list source [file join $dir devio.tcl]]
package ifneeded DM15 3.0.00 [list source [file join $dir DM15.tcl]]
package ifneeded HP15CE 1.0.00 [list source [file join $dir HP15CE.tcl]]