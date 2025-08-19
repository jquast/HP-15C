if {![package vsatisfies [package provide Tcl] 8.2]} {return}
package ifneeded math 1.2.5 [list source [file join $dir math.tcl]]
package ifneeded math::fuzzy 0.2.1 [list source [file join $dir fuzzy.tcl]]
