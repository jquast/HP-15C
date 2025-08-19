# ------------------------------------------------------------------------------
#
#             Device Input/Output Package for the HP-15C Simulator
#
#                            (c) 2025 Torsten Manz
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

package require Tcl 8.6.6-
package require HP15MEM
package require DM15
package require HP15CE
package provide DEVIO 1.0.01

namespace eval DEVIO {

  variable CONF
  array set CONF {
    interactive 1
    r_flags 0
    r_prgm 1
    r_stack 0
    r_sto 0
    r_mat 0
    w_flags 0
    w_prgm 1
    w_stack 0
    w_sto 0
    w_mat 0
    dumpdir "."
    memsize 96
  }

  variable CONFtmp
  array set CONFtmp {}

  variable DM15timefmtd ""
  variable DM15synching 0

}

# ------------------------------------------------------------------------------
# Data section

# ------------------------------------------------------------------------------
proc ::DEVIO::do_ok { wid device mode md } {

  variable CONF
  variable CONFtmp

  foreach cc {prgm sto mat stack flags} {
    set CONF($md\_$cc) $CONFtmp($md\_$cc)
  }

  destroy $wid

  ::DEVIO::$device\_$mode

}

# ------------------------------------------------------------------------------
proc ::DEVIO::do { device mode } {

  variable CONF
  variable CONFtmp

  if {$CONF(interactive)} {
    toplevel .diodata
    wm attributes .diodata -alpha 0.0
    wm title .diodata [mc menu.$device]

    if {$mode eq "read"} {
      set ftxt "[mc devio.readdata]"
      set md "r"
    } else {
      set ftxt "[mc devio.writedata]"
      set md "w"
    }

    foreach cc {prgm sto mat stack flags} {
      set CONFtmp($md\_$cc) $CONF($md\_$cc)
    }

    set fpo .diodata.outer
    ttk::frame $fpo -relief flat

# Data frame
    set fpo $fpo.data
    ttk::labelframe $fpo -text " $ftxt " -padding {20 0 20 0}

    ttk::label $fpo.lblprgm -text [mc gen.program]
    ttk::label $fpo.lblsto -text [mc gen.regs]
    ttk::label $fpo.lblmat -text [mc gen.matrices]
    ttk::label $fpo.lblstack -text [mc gen.stack]
    ttk::label $fpo.lblflags -text [mc gen.flags]

    ttk::checkbutton $fpo.prgm -variable ::DEVIO::CONFtmp($md\_prgm)
    ttk::checkbutton $fpo.sto -variable ::DEVIO::CONFtmp($md\_sto)
    ttk::checkbutton $fpo.mat -variable ::DEVIO::CONFtmp($md\_mat)
    ttk::checkbutton $fpo.stack -variable ::DEVIO::CONFtmp($md\_stack)
    ttk::checkbutton $fpo.flags -variable ::DEVIO::CONFtmp($md\_flags)

    grid $fpo.lblprgm -row 1 -column 0 -sticky w -padx 10
    grid $fpo.lblsto -row 2 -column 0 -sticky w -padx 10
    grid $fpo.lblmat -row 3 -column 0 -sticky w -padx 10
    grid $fpo.lblstack -row 4 -column 0 -sticky w -padx 10
    grid $fpo.lblflags -row 5 -column 0 -sticky w -padx 10

    grid $fpo.prgm -row 1 -column 1 -padx 20 -sticky w
    grid $fpo.sto -row 2 -column 1 -padx 20 -sticky w
    grid $fpo.mat -row 3 -column 1 -padx 20 -sticky w
    grid $fpo.stack -row 4 -column 1 -padx 20 -sticky w
    grid $fpo.flags -row 5 -column 1 -padx 20 -sticky w

    grid $fpo -row 0 -column 0 -padx 5 -pady 5 -sticky nswe

# Button frame
    set fbtn .diodata.outer.btn
    ttk::frame $fbtn -relief flat -borderwidth 5
    ttk::button $fbtn.action -text [mc gen.$mode] -default active\
      -command "::DEVIO::do_ok .diodata $device $mode $md"
    ttk::button $fbtn.cancel -text [mc gen.cancel] -command "destroy_modal .diodata"

    grid $fbtn.action -row 0 -column 0 -padx 5 -pady 5 -sticky e
    grid $fbtn.cancel -row 0 -column 1 -padx 5 -pady 5 -sticky e
    grid $fbtn -row 1 -column 0 -sticky nsew
    grid columnconfigure $fbtn 0 -weight 1

    bind .diodata <Return> "$fbtn.action invoke"
    bind .diodata <Escape> "$fbtn.cancel invoke"

    grid .diodata.outer -row 0 -column 0 -sticky nswe

    update
    set px [expr [winfo screenwidth .diodata]/2 - [winfo width .diodata]/2]
    set py [expr [winfo screenheight .diodata]/2 - [winfo height .diodata]/2]
    wm geometry .diodata +$px+$py
    wm resizable .diodata false false

    raise .diodata
    grab .diodata
    focus .diodata
    wm attributes .diodata -alpha 1.0

  } else {
    ::DEVIO::$device\_$mode
  }

}

# ------------------------------------------------------------------------------
proc ::DEVIO::getmem {} {

  variable CONF
  global HP15 status FLAG prgstat PRGM

  set MemInfo [::HP15MEM::MemInfo]

  if {$CONF(r_flags)} {
    ::HP15MEM::GetFlags FLAG
  }

  if {$CONF(r_stack)} {
    if {$FLAG(8)} {
      ::HP15MEM::GetStack ::stack ::istack
    } else {
      ::HP15MEM::GetStack ::stack
    }
  }

  if {$CONF(r_sto)} {
    if {[dict get $MemInfo dataregs] > $HP15(dataregs)} {
      error "[mc hp15mem.storagecnt]\n[mc devio.regmismatch $HP15(dataregs) [dict get $MemInfo dataregs]]"
    }
    ::HP15MEM::GetStorage ::storage
  }

  if {$CONF(r_mat)} {
    if {[dict get $MemInfo matregs] > $HP15(poolregsfree)} {
      error "[mc hp15mem.matsize]\n[mc devio.regmismatch $HP15(poolregsfree [dict get $MemInfo matregs]]"
    }
    ::HP15MEM::GetMatrices ::MAT
    set mid [expr [scan [::HP15MEM::GetResultMatrix] "%c"] - 64]
    set status(result) [Descriptor $mid]
  }

  if {$CONF(r_prgm)} {
    set regsavaible [expr $HP15(poolregsfree)+$HP15(prgmregs)]
    if {[dict get $MemInfo prgmregs] > $regsavaible} {
      error "[mc hp15mem.prgmsize]\n[mc devio.regmismatch $regsavaible [dict get $MemInfo prgmregs]]"
    }
    set PRGM [::HP15MEM::GetPrgm]

    set prgstat(curline) 0
    set prgstat(interrupt) 0
    set HP15(prgmname) ""
    set prgstat(running) 0
    set prgstat(rtnadr) {}
    array unset ::prdoc::DESC
    mem_recalc
    if {$status(PRGM)} {
      show_curline
    }
  }

  if {!$status(PRGM)} {show_x}

}

# ------------------------------------------------------------------------------
proc ::DEVIO::setmem {} {

  variable CONF
  global status PRGM

  set MemInfo [::HP15MEM::MemInfo]

  if {$CONF(w_flags)} {::HP15MEM::SetFlags ::FLAG}
  if {$CONF(w_stack)} {::HP15MEM::SetStack ::stack ::istack}
  if {$CONF(w_sto)} {::HP15MEM::SetStorage ::storage}
  if {$CONF(w_mat)} {
    ::HP15MEM::SetMatrices ::MAT
    ::HP15MEM::SetResultMatrix [format "%c" [expr 64+[string index $status(result) 1]]]
  }
  if {$CONF(w_prgm)} {::HP15MEM::SetPrgm ::PRGM}

}

# ------------------------------------------------------------------------------
# DM15 section

# ------------------------------------------------------------------------------
proc ::DEVIO::dm15_read {} {

  variable CONF

# Read data from device
  if {[catch {

    ::DM15::Open
    array unset ::HP15MEM::MEM
    ::DM15::Read ::HP15MEM::MEM
    ::DM15::Close

# If reg 0x15 or 0x16 is not set, no data has been read in
    if {![info exists ::HP15MEM::MEM([expr 0x15])] || \
      ![info exists ::HP15MEM::MEM([expr 0x16])]} {
      error "[mc devio.err.read]"
    }

  } errMsg]} {
    ::DM15::Close
    tk_messageBox -type ok -icon error -default ok \
      -title [mc menu.dm15] -message "[mc devio.readdata]:\n$errMsg"
    return
  }

# Copy data from mem to simulator
  if {[catch {
    ::DEVIO::getmem

    tk_messageBox -type ok -icon info -default ok -title [mc menu.dm15] \
      -message "[mc devio.readdata]:\n[mc devio.ok.read]"
  } errMsg]} {
    tk_messageBox -type ok -icon error -default ok -title [mc menu.dm15] \
      -message "[mc devio.readdata]:\n$errMsg"
  }

}

# ------------------------------------------------------------------------------
proc ::DEVIO::dm15_write {} {

  variable CONF

  if {[catch {

    ::DM15::Open
    array unset ::HP15MEM::MEM
    ::DM15::Read ::HP15MEM::MEM

    ::DEVIO::setmem

    ::DM15::Write ::HP15MEM::MEM
    ::DM15::Close

    tk_messageBox -type ok -icon info -default ok -title [mc menu.dm15] \
      -message "[mc devio.writedata]:\n[mc devio.ok.write]"

  } errMsg]} {
    ::DM15::Close
    tk_messageBox -type ok -icon error -default ok \
      -title [mc menu.dm15] -message "[mc devio.writedata]:\n$errMsg"
  }

}

# ------------------------------------------------------------------------------
proc ::DEVIO::synctime {} {

  variable CONF
  variable DM15synching

  if {$DM15synching} { return }

  if {[catch {
    set DM15synching 1
    ::DM15::Open
    ::DM15::WriteTime
    set DM15status [::DM15::ReadStatus]
    ::DM15::Close
    ::DEVIO::timefmtd [dict get $DM15status datetime]
    set DM15synching 0

  } errMsg]} {
    ::DM15::Close
    set DM15synching 0
    tk_messageBox -type ok -icon error -default ok \
      -title [mc menu.dm15] -message "[mc devio.writedata]:\n$errMsg"
  }

}

# ------------------------------------------------------------------------------
proc ::DEVIO::timefmtd { tval } {

  variable DM15timefmtd

  set pct [clock seconds]
  set tdelta [format {(%+ds)} [expr $tval - $pct]]
  set DM15timefmtd "[clock format $tval -format {%Y-%m-%d %H:%M:%S}] $tdelta"

}

# ------------------------------------------------------------------------------
proc ::DEVIO::dm15sysinfo {} {

  variable CONF

  if {[catch {

    ::DM15::Open

    set DM15status [::DM15::ReadStatus]
    ::DM15::Close

  } errMsg]} {
    ::DM15::Close
    tk_messageBox -type ok -icon error -default ok \
      -title "DM15" -message "[mc devio.readdata]:\n$errMsg"
    return
  }

  toplevel .dm15si
  wm title .dm15si [mc menu.dm15]
  wm attributes .dm15si -alpha 0.0

# Status frame
  set fps .dm15si.status
  ttk::labelframe $fps -text " [mc devio.dm15.sysinfo] "

# Firmware
  ttk::label $fps.lblfwt -text "[mc devio.dm15.fw]: "
  array set fwregs { CONF 64 DM15_M80 128 DM15_M1B 229 }
  set fwt [dict get $DM15status fwtype]
  ttk::label $fps.fwt -text "$fwt ($fwregs($fwt) [mc gen.regs])"

  ttk::label $fps.lblfwv -text "[mc gen.version]: "
  ttk::label $fps.fwv -text [dict get $DM15status fwversion]

  grid $fps.lblfwt -row 0 -column 0 -padx 10 -sticky w
  grid $fps.fwt -row 0 -column 1 -sticky w
  grid $fps.lblfwv -row 1 -column 0 -padx 10 -sticky w
  grid $fps.fwv -row 1 -column 1 -sticky w

# Time
  if {[dict exists $DM15status datetime]} {
    ::DEVIO::timefmtd [dict get $DM15status datetime]

    ttk::label $fps.lbltime -text "[mc devio.dm15.datetime]: "
    ttk::label $fps.time -textvariable ::DEVIO::DM15timefmtd
    ttk::button $fps.sync -text "[mc devio.dm15.sync]" -command "::DEVIO::synctime"

    grid $fps.lbltime -row 2 -column 0 -padx 10 -sticky w
    grid $fps.time -row 2 -column 1 -sticky w
    grid $fps.sync -row 2 -column 2 -padx 10 -sticky w
  }

# Battery
  if {[dict exists $DM15status battery]} {
    ttk::label $fps.lblbat -text "[mc gen.voltage]: "
    set bat [dict get $DM15status battery]
    foreach {blevel bp} [list 2800 ">50%" 2700 ">25%" 2300 ">10%" 0 "<10%"] {
      if {$bat >= $blevel} {
        set bt $bp
        break
      }
    }
    ttk::label $fps.bat -text "$bat mV ([mc devio.dm15.remainpower] $bt)"

    grid $fps.lblbat -row 3 -column 0 -padx 10 -sticky w
    grid $fps.bat -row 3 -column 1 -sticky w
  }

  grid $fps -row 0 -column 0 -padx 5 -pady 5 -sticky nwse

# Button frame
  set fbtn .dm15si.btn
  ttk::frame $fbtn -relief flat -borderwidth 5
  ttk::button $fbtn.ok -text [mc gen.ok] -command "destroy_modal .dm15si"

  grid $fbtn.ok -row 0 -column 1 -padx 5 -pady 5 -sticky e
  grid $fbtn -row 1 -column 0 -sticky nwse
  grid columnconfigure $fbtn 0 -weight 1

  bind .dm15si <Return> "$fbtn.ok invoke"
  bind .dm15si <Escape> "$fbtn.ok invoke"

  update
  set px [expr [winfo screenwidth .dm15si]/2 - [winfo width .dm15si]/2]
  set py [expr [winfo screenheight .dm15si]/2 - [winfo height .dm15si]/2]
  wm geometry .dm15si +$px+$py
  wm resizable .dm15si false false

  raise .dm15si
  grab .dm15si
  focus .dm15si
  wm attributes .dm15si -alpha 1.0

}

# ------------------------------------------------------------------------------
# HP-15C CE section

# ------------------------------------------------------------------------------
proc ::DEVIO::hp15ce_memsize { regs } {

  variable CONF

  set CONF(memsize) $regs

}

# ------------------------------------------------------------------------------
proc ::DEVIO::hp15ce_read {} {

  variable CONF

# Choose memory dump file
  if {![file exists $CONF(dumpdir)]} {
    set CONF(dumpdir) [pwd]
  }

  set HP15CE_FILETYPES [list [list [mc devio.hp15ce.memfile] [list ".15CE" ".HP15CE"]] \
    [list [mc app.extall] ".*"]]

  set fnam [tk_getOpenFile -title [mc devio.hp15ce.read] \
    -filetypes $HP15CE_FILETYPES -initialdir $CONF(dumpdir) -defaultextension "15CE"]

# WA-MAC: After system dialogues, the focus is not always on the gui since 8.6.8
  if {$::tcl_platform(os) eq "Darwin"} {
    focus -force .gui
  }

  if {$fnam eq ""} { return }

# Read data from file
  if {[catch {
    array unset ::HP15MEM::MEM
    ::HP15CE::Read $fnam ::HP15MEM::MEM

# If reg 0x15 or 0x16 is not set, no data has been read in
    if {![info exists ::HP15MEM::MEM([expr 0x15])] || \
      ![info exists ::HP15MEM::MEM([expr 0x16])]} {
      error "[mc devio.err.read]"
    }
  } errMsg]} {
    tk_messageBox -type ok -icon error -default ok \
      -title [mc menu.hp15ce] -message "[mc devio.readdata]:\n$errMsg"
    return
  }

# Copy data from mem to simulator
  if {[catch {

    ::DEVIO::getmem

    tk_messageBox -type ok -icon info -default ok -title [mc menu.hp15ce] \
      -message "[mc devio.readdata]:\n[mc devio.ok.read]"
    set CONF(dumpdir) [file dirname $fnam]

  } errMsg]} {
    tk_messageBox -type ok -icon error -default ok -title [mc menu.hp15ce] \
      -message "[mc devio.readdata]:\n$errMsg"
  }

}

# ------------------------------------------------------------------------------
proc ::DEVIO::hp15ce_write {} {

  variable CONF
  global status HP15 FLAG

# Choose memory dump file
  if {![file exists $CONF(dumpdir)]} {
    set CONF(dumpdir) [pwd]
  }

  set HP15CE_FILETYPES [list [list [mc devio.hp15ce.memfile] [list ".15CE" ".HP15CE"]] \
    [list [mc app.extall] ".*"]]

  set fnam [tk_getSaveFile -title [mc devio.hp15ce.write] \
    -filetypes $HP15CE_FILETYPES -initialdir $CONF(dumpdir) -defaultextension "15CE"]

# WA-MAC: After system dialogues, the focus is not always on the gui since 8.6.8
  if {$::tcl_platform(os) eq "Darwin"} {
    focus -force .gui
  }
  if {$fnam eq ""} { return }

  if {[catch {

# Writing a file via default memory layout
    array unset ::HP15MEM::MEM
    ::HP15CE::InitMem ::HP15MEM::MEM $CONF(memsize) $FLAG(8)

# If reg 0x15 or 0x16 is not set, no data has been read in
    if {![info exists ::HP15MEM::MEM([expr 0x15])] || \
      ![info exists ::HP15MEM::MEM([expr 0x16])]} {
      error "[mc devio.err.read]"
    }

# Configure CE memory according to simulator settings

# Set decimal point as in simulator
    if {$status(comma) eq ","} {
      ::HP15MEM::SetByte 5 1 08
    } else {
      ::HP15MEM::SetByte 5 1 0c
    }

# Set number of storage regs
    set dregs $HP15(dataregs)
    if {$CONF(memsize) == 96 && $dregs > 96} {
      set dregs 96
    }
    set badr 0x[::HP15MEM::GetByte 15 7]
    set radr [format "%02x" [expr $badr + $dregs - 1]]
    for {set ii 1} {$ii < 7} {incr ii} {
      ::HP15MEM::SetByte 15 $ii $radr
    }

# Merge simulator data into CE memory
    ::DEVIO::setmem

# Write CE mem to file
    ::HP15CE::Write $fnam ::HP15MEM::MEM

    tk_messageBox -type ok -icon info -default ok -title [mc menu.hp15ce] \
      -message "[mc devio.writedata]:\n[mc devio.ok.write]"
    set CONF(dumpdir) [file dirname $fnam]

  } errMsg]} {
    tk_messageBox -type ok -icon error -default ok \
      -title [mc menu.hp15ce] -message "[mc devio.writedata]:\n$errMsg"
  }

}