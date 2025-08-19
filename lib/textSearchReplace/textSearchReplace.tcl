# ------------------------------------------------------------------------------
#
#                            textSearchReplace
#
# ------------------------------------------------------------------------------

package provide textSearchReplace 0.5.1

# ------------------------------------------------------------------------------
namespace eval textSearchReplace {

  variable SEARCH
  array set SEARCH {
    case -nocase
    count ""
    direction -forwards
    markcolour yellow
    regexp ""
  }

}

# ------------------------------------------------------------------------------
proc ::textSearchReplace::setDirection { dir } {

  variable SEARCH

  if {$dir eq "forward"} {
    set SEARCH(direction) "-forwards"
  } elseif {$dir eq "backward"} {
    set SEARCH(direction) "-backwards"
  }
}

# ------------------------------------------------------------------------------
proc ::textSearchReplace::setCase { state } {

  variable SEARCH

  if {$state} {
    set SEARCH(case) ""
  } else {
    set SEARCH(case) "-nocase"
  }

}

# ------------------------------------------------------------------------------
proc ::textSearchReplace::setRegexp { state } {

  variable SEARCH

  if {$state} {
    set SEARCH(regexp) "-regexp"
  } else {
    set SEARCH(regexp) ""
  }

}

# ------------------------------------------------------------------------------
proc ::textSearchReplace::setMarkColour { col } {

  variable SEARCH

  catch {
    if {"[winfo rgb . $col]" ne ""} {
      set SEARCH(markcolour) $col
    }
  }

}

# ------------------------------------------------------------------------------
proc ::textSearchReplace::unBackslash { text } {

  string map [list \\\\ \\ \\n \n \\t \t] $text

}

# ------------------------------------------------------------------------------
proc ::textSearchReplace::basicSearchString { win } {
# create command out of array SEARCH(...)

  variable SEARCH

  lappend result $win search -count ::textSearchReplace::SEARCH(count) \
    {*}$SEARCH(direction) {*}$SEARCH(case) {*}$SEARCH(regexp)

}

# ------------------------------------------------------------------------------
proc ::textSearchReplace::find { win searchstr } {
# return indices of searchstr

  variable SEARCH

  if {$searchstr eq ""} {
    return {}
  }

  if {$SEARCH(direction) eq "-backwards"} then {
    if {[$win tag ranges sel] eq ""} then {
      set from insert
    } else {
      set from sel.first
    }
    set to 1.0
  } else {
    if {[$win tag ranges sel] eq ""} then {
      set from insert
    } else {
      set from sel.last
    }
    set to end
  }
  set txt $searchstr
  if {$SEARCH(regexp) eq ""} then {
    set txt [::textSearchReplace::unBackslash $txt]
  }
  set SEARCH(count) ""
  set idx [{*}[::textSearchReplace::basicSearchString $win] -- $txt $from $to]
  if {$idx ne ""} then {
    list $idx [$win index $idx+$SEARCH(count)chars]
  }

}

# ------------------------------------------------------------------------------
proc ::textSearchReplace::findSelect { win searchstr } {
# find and select

  $win tag remove textSRMark 1.0 end
  set indices [::textSearchReplace::find $win $searchstr]
  $win tag remove sel 1.0 end
  if {$indices ne ""} then {
    $win tag add sel {*}$indices
    $win mark set insert sel.first
    $win see insert
    focus -force $win
  }

}

# ------------------------------------------------------------------------------
proc ::textSearchReplace::replace { win searchstr replacestr} {
# replace found text

  variable SEARCH

  if {[$win tag ranges sel] ne ""} then {
    set replaceText $replacestr
    lassign [$win tag ranges sel] from to
    set selection [$win get $from $to]
    set selText [$win get $from $to]
    if {$SEARCH(regexp) eq ""} then {
      if {$selText eq [unBackslash $searchstr]} then {
        $win configure -autoseparators no
        $win edit separator
        $win delete $from $to
        $win insert $from [unBackslash $replaceText]
        $win edit separator
        $win configure -autoseparators yes
        focus -force $win
      }
    } else {
      if {[regexp $searchstr $selText match] &&
          $match eq $selText} then {
        regsub {*}$SEARCH(case) $searchstr $selText $replacestr replace
        $win configure -autoseparators no
        $win edit separator
        $win delete $from $to
        $win insert $from [unBackslash $replace]
        $win edit separator
        $win configure -autoseparators yes
        focus -force $win
      }
    }
  }

}

# ------------------------------------------------------------------------------
proc ::textSearchReplace::findAll {win searchstr {from 1.0} {to end}} {
# return bounds of all occurrences

  variable SEARCH

  set dir $SEARCH(direction)
  set SEARCH(direction) -forwards
  lappend result
  set text [unBackslash $searchstr]
  set SEARCH(count) ""
  set indices [{*}[basicSearchString $win] -all -- $text $from $to]
  set SEARCH(direction) $dir
  if {$indices ne ""} then {
    foreach idx $indices len $SEARCH(count) {
      lappend result $idx [$win index $idx+${len}chars]
    }
    set result
  }

}

# ------------------------------------------------------------------------------
proc ::textSearchReplace::markAll { win searchstr } {
# hilight all occurrences

  variable SEARCH

  $win tag remove textSRMark 1.0 end
  if {$searchstr ne ""} then {
    $win tag configure textSRMark -background $SEARCH(markcolour)
    $win tag lower textSRMark sel
    foreach {from to} [::textSearchReplace::findAll $win $searchstr] {
      $win tag add textSRMark $from $to
    }
  }

}

# ------------------------------------------------------------------------------
proc ::textSearchReplace::replaceAll { win searchstr replacestr } {
# replace all occurrences in certain range

  variable SEARCH

  set replaceText $replacestr
  if {$SEARCH(regexp) eq ""} then {
    set replaceText [unBackslash $replaceText]
  }
  if {[$win tag ranges sel] ne ""} then {
    # range: sel
    lassign [$win tag ranges sel] fromRange toRange
  } elseif {$SEARCH(direction) eq "-backwards"} then {
    # range: start to insert
    lassign "1.0 insert" fromRange toRange
  } else {
    # range: insert to end
    lassign "insert end" fromRange toRange
  }
  $win configure -autoseparators no
  $win edit separator
  foreach {to from} [lreverse [::textSearchReplace::findAll $win $searchstr \
    $fromRange $toRange]] {
    if {$SEARCH(regexp) eq ""} then {
      $win delete $from $to
      $win insert $from $replaceText
    } else {
      regsub {*}$SEARCH(case) \
        $searchstr [$win get $from $to] $replacestr \
        ::textSearchReplace::replace
      $win delete $from $to
      $win insert $from [::textSearchReplace::unBackslash $replacestr]
    }
  }
  $win see insert
  $win edit separator
  $win configure -autoseparators yes

}
