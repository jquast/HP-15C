# ------------------------------------------------------------------------------
#
#                    DM15 Package for the HP-15C Simulator
#
#                         (c) 2012-2025 Torsten Manz
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
package provide DM15 3.0.00

namespace eval ::DM15 {

  variable LogCmd ""

  variable COM
  array set COM {
    id ""
    WaitTimeout 0
  }

  variable CONF
  array set CONF {
    serialport ""
    spdriver "slabs"
    timeout 5
  }

  variable ReadBuffer ""

  variable FWREGS
  array set FWREGS {
    "DM15" 64
    "DM15_M80" 128
    "DM15_M1B" 229
  }

}
#

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
proc ::DM15::comport {} {

  variable CONF

  set rc ""

  if {$::tcl_platform(os) eq "Darwin"} {
    if {$CONF(spdriver) eq "slabs"} {
      set rc "/dev/cu.SLAB_USBtoUART"
    } elseif {$CONF(serialport) ne ""} {
      set rc "/dev/cu.usbserial-[format {%04d} $CONF(serialport)]"
    }
  } elseif {$CONF(serialport) ne ""} {
    if {$::tcl_platform(platform) eq "unix"} {
      set rc "/dev/ttyUSB$CONF(serialport)"
    } else {
      set rc "\\\\.\\com$CONF(serialport)"
    }
  }

  return $rc

}

# ------------------------------------------------------------------------------
proc ::DM15::Open {} {

  variable COM
  variable CONF

  if {$COM(id) != ""} { return }

  set COM(WaitTimeout) 0
  set device [comport]
  if {$device eq ""} {
    error "[mc dm15.err.noport]"
  }

  if {[catch {open $device RDWR} fid options]} {
    ::DM15::Log "$::errorCode - $::errorInfo" error
    error "[mc dm15.err.open $CONF(serialport)]"
  } else {
    set COM(id) $fid
# On some Linux systems /dev/ttyUSB# might not be recognized as a serial device
    if {[catch {fconfigure $COM(id) -mode 38400,n,8,1}]} {
      ::DM15::Close
      error "[mc dm15.err.noserialdev $device]"
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
  variable CONF

  set afterId [after [expr $CONF(timeout)*1000] ::DM15::WaitTimeout]
  vwait ::DM15::COM(ReadComplete)
  catch {after cancel $afterId}
  if {$COM(WaitTimeout) == 1} {
    error "[mc dm15.err.timeout]"
  }

}

# ------------------------------------------------------------------------------
# Data section

# ------------------------------------------------------------------------------
proc ::DM15::DecodeMem { data } {

  variable FWREGS
  set REGS {}

# Detect firmware
  regexp {(DM15(CC)*[^\n]*)} $data fw

  if {[catch {
    set totregs $FWREGS($fw)
  }]} {
    error "[mc dm15.fw.notidentified]"
  }
  lappend REGS "FW" $fw "TOTREGS" $totregs

  foreach ll [split $data "\n"] {
    regsub -all " +" [string trim $ll] " " ll
    if {[regexp {(^[0-9a-f][0-9a-f]) (.*)} $ll ign adr dat]} {
      set reg [expr 0x$adr]
      foreach rr [split $dat " "] {
        lappend REGS $reg $rr
        incr reg
      }
    } elseif {[regexp {^[A-Z]: .*} $ll ign]} {
      foreach {reg val} [split $ll " "] {
        lappend REGS -[scan $reg "%c"] $val
      }
    }
  }

  return $REGS

}

# ------------------------------------------------------------------------------
proc ::DM15::EncodeMem { MEM } {

  upvar $MEM mem

  if {![info exists mem(FW)]} {
    error "[mc hp15mem.notinit]"
  }
  set rc $mem(FW)

# Encode registers 00-1F
  for {set reg 0} {$reg < 256} {incr reg} {
    if {[info exists mem($reg)]} {
      if {$reg % 4 == 0} {
        append rc "\n[format "%02x" $reg]"
      }
      append rc "  " $mem($reg)
    }
  }

# Encode registers A, B, C, S, M, N, and G
  append rc "\n"
  foreach reg {-65 -66 -67 -83 -77 -78 -71} {
    if {[info exists mem($reg)]} {
      append rc "[format "%c:" [expr abs($reg)]] $mem($reg)"
      if {$reg in {-67 -83}} {
        append rc "\n"
      } elseif {$reg != "-71"} {
        append rc "  "
      }
    } else {
      error "[mc hp15mem.notinit]"
    }

  }

  return $rc

}

# ------------------------------------------------------------------------------
proc ::DM15::Read { MEM } {

  variable ReadBuffer ""
  variable COM
  upvar $MEM mem

  fileevent $COM(id) readable [list ::DM15::ReadCB "VOYAGER >>"]
  Send "s"
  Wait

  array set mem [::DM15::DecodeMem $ReadBuffer]

}

# ------------------------------------------------------------------------------
proc ::DM15::Write { MEM } {

  variable ReadBuffer ""
  variable COM
  upvar $MEM mem

  set data [::DM15::EncodeMem mem]

  fileevent $COM(id) readable [list ::DM15::ReadCB "Waiting for data"]
  Send "l"
  Wait
  fileevent $COM(id) readable [list ::DM15::ReadCB "VOYAGER >>"]
  Send "$data"
  Wait

  if {[string first "Read OK" $ReadBuffer ] < 0} {
    error "[mc dm15.err.write]"
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