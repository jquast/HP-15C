# ------------------------------------------------------------------------------
#
#            Program Dcoumentation Package for the HP-15C Simulator
#
#                          (c) 2017-2025 Torsten Manz
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

package require Tcl 8.6-
package require math
package require htmlTagAttr
package require history
package require textSearchReplace
package provide prdoc 2.5.1

namespace eval ::prdoc {

  variable geomRE {=?((\d+)x(\d+))?([+-])(-?\d+)([+-])(-?\d+)}
  variable prevpos ""

  variable CONF
  array set CONF {
    autopreview 1
    markcolour yellow
    ShowResTab 1
    tagbold 1
    tagcolour #800080
    taghighlight 1
    toolbarstyle icons
    unicodesyms 1
  }
  if {[tk windowingsystem] eq "aqua"} {
    set CONF(tagmenuicons) 0
  } else {
    set CONF(tagmenuicons) 1
  }

  variable STATUS
  array set STATUS {
    case 0
    regexp 0
    replace ""
    search ""
    searchdir forward
    showresources 1
  }
  set STATUS(searchhist) [::history::create 15]
  set STATUS(replacehist) [::history::create 15]

# Bindings for Usage text field
  variable ADDTAG_BINDS
  array set ADDTAG_BINDS {
    a         {ctrl shift A}
    code      {ctrl shift C}
    em        {ctrl shift I}
    fKey      {ctrl opt f}
    fKeyLabel {ctrl shift F}
    gKey      {ctrl opt g}
    gKeyLabel {ctrl shift G}
    KeyLabel  {ctrl shift K}
    li        {ctrl shift L}
    ol        {ctrl shift O}
    pre       {ctrl shift P}
    register  {ctrl shift R}
    strong    {ctrl shift B}
    sup       {ctrl shift S}
    sub       {ctrl shift T}
    ul        {ctrl shift U}
  }

  variable ADDCHAR_BINDS
  array set ADDCHAR_BINDS {
    emdash  {ctrl underscore  "\u2014"}
    rarr    {ctrl greater     "\u2192"}
    larr    {ctrl less        "\u2190"}
    middot1 {ctrl asterisk    "\u00B7"}
    middot2 {ctrl KP_Multiply "\u00B7"}
  }

# OS specific settings
  variable LAYOUT
  variable MODKEY

  if {[tk windowingsystem] eq "aqua"} {
    set LAYOUT(btnwid) 3
    set LAYOUT(tabpad) [list 0 8 0 3]

    array set MODKEY {
      ctrl "Command"
      opt "Option"
      shift "Shift"
    }
    array set ADDTAG_BINDS {
      a  {ctrl opt a}
      li {ctrl opt l}
    }

    array unset ADDCHAR_BINDS ?arr

  } else {
    set LAYOUT(btnwid) 4
    set LAYOUT(tabpad) [list 8 8 6 3]

    array set MODKEY {
      ctrl "Control"
      opt "Alt"
      shift "Shift"
    }
  }

# Description variables
  variable DESC
  array set DESC {}
  variable DESC_T
  array set DESC_T {}
  variable DocuChanged 0

  variable MARKS
  array set MARKS { L {} R {} F {} }

# Fonts and styles for HTML rendering
  set basesize [font actual TkTextFont -size]
# WA-Linux: "font actual" returns "-size 0" for Tk standard fonts
  if {$basesize <= 0} {
    set basesize [expr int([font metrics TkFixedFont -linespace]*0.65)]
  }
  foreach {tt fs wt} {h1 6 bold h2 4 bold h3 3 bold h4 2 bold h5 1 bold \
    h6 0 bold strong 0 bold em 0 normal emstrong 0 bold reg 0 bold keyface 1 bold \
    sub -2 normal} {
    font create FnPrDoc$tt -family [font actual TkTextFont -family] \
      -size [expr $basesize+$fs] -weight $wt
  }
  font configure FnPrDocem -slant italic
  font configure FnPrDocemstrong -slant italic
  font configure FnPrDocreg -family Times -weight bold -size [expr int($basesize*1.2)]

  font create FnFixem {*}[font actual TkFixedFont]
  font configure FnFixem -weight normal -slant italic
  font create FnFixstrong {*}[font actual TkFixedFont]
  font configure FnFixstrong -weight bold
  font create FnFixemstrong {*}[font actual TkFixedFont]
  font configure FnFixemstrong -weight bold -slant italic

  set fam [font actual TkFixedFont -family]
  font create FnCode -family $fam -size $basesize
  font create FnCodeem -family $fam -size $basesize -weight normal -slant italic
  font create FnCodestrong -family $fam -size $basesize -weight bold
  font create FnCodeemstrong -family $fam -size $basesize -weight bold -slant italic

# Font for superscript/subscript sub-menu
  font create FnPrSupsub {*}[font actual TkMenuFont]
  font configure FnPrSupsub -size [expr int([font configure TkMenuFont -size]*1.4)]

  variable TagStyle
  array set TagStyle {
    h1 {{<h1>} {</h1>} {-font FnPrDoch1}}
    h2 {{<h2>} {</h2>} {-font FnPrDoch2}}
    h3 {{<h3>} {</h3>} {-font FnPrDoch3}}
    h4 {{<h4>} {</h4>} {-font FnPrDoch4}}
    h5 {{<h5>} {</h5>} {-font FnPrDoch5}}
    h6 {{<h6>} {</h6>} {-font FnPrDoch6}}
    bold {{<b>} {</b>} {-font FnPrDocstrong}}
    strong {{<strong>} {</strong>} {-font FnPrDocstrong}}
    i {{<i>} {</i>} {-font FnPrDocem}}
    em {{<em>} {</em>} {-font FnPrDocem}}
    pre {{<pre>} {</pre>} {-font TkFixedFont -back #F0F0F0}}
    code {{<code>} {</code>} {-font FnCode}}
    ol {{<ol>} {</ol>} {}}
    ul {{<ul>} {</ul>} {}}
    li {{<li>} {</li>} {}}
    lili {{<li>} {</li>} {}}
    a {{<a[^>]+>} {</a>} {-fore blue}}
    KeyLabel {{<span class="HP15CKey">} {</span>} \
      {-font FnPrDockeyface -fore white -back #454545}}
    fKeyLabel {{<span class="HP15CfKeyLabel">} \
      {</span>} {-font FnPrDockeyface -fore #E1A83E -back #454545}}
    gKeyLabel {{<span class="HP15CgKeyLabel">} \
      {</span>} {-font FnPrDockeyface -fore #6CB7BD -back #454545}}
    fKey {{<span class="HP15CfKey">} {</span>} \
      {-font FnPrDockeyface -fore black -back #E1A83E}}
    gKey {{<span class="HP15CgKey">} {</span>} \
      {-font FnPrDockeyface -fore black -back #6CB7BD}}
    register {{<span class="HP15CRegister">} {</span>} {-font FnPrDocreg}}
    noimage {{<img("[^"]*"|'[^']*'|[^'">])*} {>} {-font FnPrDocstrong \
      -back #F0F0F0  -justify center -lmargin1 30 -rmargin 30}}
  }
  set TagStyle(sup) [list <sup> </sup> [list -font FnPrDocsub -offset [expr $basesize/2]]]
  set TagStyle(sub) [list <sub> </sub> [list -font FnPrDocsub -offset [expr -$basesize/2]]]

  ttk::style configure strong.TButton -font FnPrDocstrong -width 3
  ttk::style configure em.TButton -font FnPrDocem -width 3
  ttk::style configure pre.TButton -font TkFixedFont -width 4
  ttk::style configure reg.TButton -font FnPrDocreg -width 4
  ttk::style configure tag.TButton -width 4
  ttk::style configure gold.TButton -font FnPrDocstrong -foreground #E1A83E -width 4
  ttk::style configure blue.TButton -font FnPrDocstrong -foreground #6CB7BD -width 4
  ttk::style configure fkey.TButton -font FnPrDocstrong -foreground #E1A83E -width 3
  ttk::style configure gkey.TButton -font FnPrDocstrong -foreground #6CB7BD -width 3

# WA-macOS: The standard button padding is much to wide
  if {[tk windowingsystem] eq "aqua"} {
    foreach st [list strong em pre reg tag gold blue fkey gkey] {
      ttk::style configure $st.TButton -padding -17
    }
  }

  variable Symbols
  set Symbols(greek) {
    &Alpha; \u0391 &Beta; \u0392 &Gamma; \u0393 &Delta; \u0394 Epsilon; \u0395
    &Zeta; \u0396 &Eta; \u0397 &Theta; \u0398 &Iota; \u0399 &Kappa; \u039a
    &Lambda; \u039b &Mu; \u039c &Nu; \u039d &Xi; \u039e &Omicron; \u039f
    &Pi; \u03a0 &Rho; \u03a1 &Sigma; \u03a3 &Tau; \u03a4 &Upsilon; \u03a5
    &Phi; \u03a6 &Chi; \u03a7 &Psi; \u03a8 &Omega; \u03a9 &alpha; \u03b1
    &beta; \u03b2 &gamma; \u03b3 &delta; \u03b4 &epsilon; \u03b5 &zeta; \u03b6
    &eta; \u03b7 &theta; \u03b8 &iota; \u03b9 &kappa; \u03ba &lambda; \u03bb
    &mu; \u03bc &nu; \u03bd &xi; \u03be &omicron; \u03bf &pi; \u03c0 &rho; \u03c1
    &sigma; \u03c3 &tau; \u03c4 &upsilon; \u03c5 &phi; \u03c6
    &chi; \u03c7 &psi; \u03c8 &omega; \u03c9 &thetasym; \u03d1 &piv; \u03d6 \
    &sigmaf; \u03c2
  }

  set Symbols(arrows) {
    &larr; \u2190 &uarr; \u2191 &rarr; \u2192 &darr; \u2193 &harr; \u2194
    &crarr; \u21b5 &lArr; \u21d0 &uArr; \u21d1 &rArr; \u21d2 &dArr; \u21d3
    &hArr; \u21d4
  }

  set Symbols(math) {
    &divide; \u00f7 &frasl; \u2044 &times; \u00d7 &minus; \u2212 &plusmn; \u00b1
    &not; \u00ac &weierp; \u2118 &image; \u2111
    &real; \u211c &trade; \u2122 &alefsym; \u2135 &forall; \u2200
    &part; \u2202 &exist; \u2203 &empty; \u2205 &nabla; \u2207 &isin; \u2208
    &notin; \u2209 &ni; \u220b &prod; \u220f &sum; \u2211
    &lowast; \u2217 &radic; \u221a &prop; \u221d &infin; \u221e &ang; \u2220
    &and; \u2227 &or; \u2228 &cap; \u2229 &cup; \u222a &int; \u222b \
    &there4; \u2234 &sim; \u223c &cong; \u2245 &asymp; \u2248 &ne; \u2260 \
    &equiv; \u2261 &lt; \u003c &gt; \u003e &le; \u2264 &ge; \u2265 &sub; \u2282 \
    &sup; \u2283  &nsub; \u2284 &sube; \u2286 &supe; \u2287 &oplus; \u2295 \
    &otimes; \u2297 &perp; \u22a5 &mitdot; \u00B7 &sdot; \u22c5 &lceil; \u2308 \
    &rceil; \u2309 &lfloor; \u230a &rfloor; \u230b &lang; \u2329 &rang; \u232a \
    &loz; \u25ca
  }

  set Symbols(supersub) {
    &#8304; \u2070 &#185; \u00B9 &#178; \u00B2 &#179; \u00B3 &#8308; \u2074
    &#8309; \u2075 &#8310; \u2076 &#8311; \u2077 &#8312; \u2078 &#8313; \u2079
    &#8320; \u2080 &#8321; \u2081 &#8322; \u2082 &#8323; \u2083 &#8324; \u2084
    &#8325; \u2085 &#8326; \u2086 &#8327; \u2087 &#8328; \u2088 &#8329; \u2089
    &#8305; \u2071 &#8319; \u207F &#8314; \u207A &#8315; \u207B &#7522; \u1D62
    &#11388; \u2C7C &#8345; \u2099 &#83330; \u208A &#8331; \u208B
  }

  set Symbols(moresyms) {
    &euro; \u20ac &cent; \u00a2 &pound; \u00a3 &yen; \u00a5 &copy; \u00a9
    &reg; \u00ae &ordf; \u00aa &ordm; \u00ba &laquo; \u00ab &raquo; \u00bb
    &sup1; \u00b9 &sup2; \u00b2 &sup3; \u00b3 &micro; \u00b5 &para; \u00b6
    &frac14; \u00bc &frac12; \u00bd &frac34; \u00be &fnof; \u0192
    &bull; \u2022 &spades; \u2660 &clubs; \u2663 &hearts; \u2665 &diams; \u2666
    &hellip; \u2026 &amp; \u0026 &brvbar; \u00a6 &tilde; \u02dc &ndash; \u2013
    &mdash; \u2014 &permil; \u2030
  }

  set Symbols(other) {
    &deg; \u00b0 &nbsp; \u00a0 &iexcl; \u00a1 &curren; \u00a4 &sect; \u00a7
    &uml; \u00a8 &Agrave; \u00c0 &Aacute; \u00c1 &Acirc; \u00c2 &Atilde; \u00c3
    &Auml; \u00c4 &Aring; \u00c5 &AElig; \u00c6 &Ccedil; \u00c7 &Egrave; \u00c8
    &Eacute; \u00c9 &Ecirc; \u00ca &Euml; \u00cb &Igrave; \u00cc &Iacute; \u00cd
    &Icirc; \u00ce &Iuml; \u00cf &ETH; \u00d0 &Ntilde; \u00d1 &Ograve; \u00d2
    &Oacute; \u00d3 &Ocirc; \u00d4 &Otilde; \u00d5 &Ouml; \u00d6 &Oslash; \u00d8
    &Ugrave; \u00d9 &Uacute; \u00da &Ucirc; \u00db &Uuml; \u00dc &Yacute; \u00dd
    &szlig; \u00df &agrave; \u00e0 &aacute; \u00e1 &acirc; \u00e2 &atilde; \u00e3
    &auml; \u00e4 &aring; \u00e5 &aelig; \u00e6 &ccedil; \u00e7 &egrave; \u00e8
    &eacute; \u00e9 &ecirc; \u00ea &euml; \u00eb &igrave; \u00ec &iacute; \u00ed
    &icirc; \u00ee &iuml; \u00ef &eth; \u00f0 &ntilde; \u00f1 &ograve; \u00f2
    &oacute; \u00f3 &ocirc; \u00f4 &otilde; \u00f5 &ouml; \u00f6 &oslash; \u00f8
    &ugrave; \u00f9 &uacute; \u00fa &ucirc; \u00fb &uuml; \u00fc &yacute; \u00fd
    &thorn; \u00fe &THORN; \u00de &yuml; \u00ff &OElig; \u0152 &oelig; \u0153
    &Scaron; \u0160 &scaron; \u0161 &Yuml; \u0178 &shy; \u00ad &macr; \u00af
    &ensp; \u2002 &emsp; \u2003 &thinsp; \u2009 &zwnj; \u200c &zwj; \u200d
    &lrm; \u200e &rlm; \u200f &acute; \u00b4 &middot; \u00b7 &cedil; \u00b8
    &iquest; \u00bf &upsih; \u03d2 &prime; \u2032 &Prime; \u2033 &oline; \u203e
    &quot; \u0022 &circ; \u02c6 &lsquo; \u2018 &rsquo; \u2019 &sbquo; \u201a
    &ldquo; \u201c &rdquo; \u201d &bdquo; \u201e &dagger; \u2020 &Dagger; \u2021
    &lsaquo; \u2039 &rsaquo; \u203a
  }

  variable HTMLentities
  set HTMLentities [concat $Symbols(greek) $Symbols(arrows) $Symbols(math) \
    $Symbols(supersub) $Symbols(moresyms) $Symbols(other)]

  set ::prdoc::ICONS(pre) [image create photo -data {
    iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABHNCSVQICAgIfAhkiAAAABt0RVh0
    U29mdHdhcmUAVGsgVG9vbGtpdCB2OC42LjExRN9eGgAAAFVJREFUeJxj+P//PwMlGEIwMBwF4v8k
    4iPIBhwhw4DDcAMo9gI9wuAIFnUkhcFhLOoGcRhg8y9J6QCbf4doOvgBxN5A7ANlk5wXQJq8oIZg
    M4A6YQAAtl0dg0IvLygAAAAASUVORK5CYII=
  }]
  set ::prdoc::ICONS(code) [image create photo -data {
    iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABHNCSVQICAgIfAhkiAAAABt0RVh0
    U29mdHdhcmUAVGsgVG9vbGtpdCB2OC42LjExRN9eGgAAAHBJREFUeJxj+P//PwMlGEIwMBwF4v9Q
    fASL2H90eXQDjiApOIxF7D+6PIoBFHuB6gbg8P9tIOZEkjuCzwBs/r8FNeAISlgNiTD4AcTeQOwD
    Zf8nNQxAmryghiAbMJjCAE+6x0j7uAzAle4x0j7VvQAAoKFXieOufnkAAAAASUVORK5CYII=
  }]
  set ::prdoc::ICONS(sup) [image create photo -data {
    iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABHNCSVQICAgIfAhkiAAAABt0RVh0
    U29mdHdhcmUAVGsgVG9vbGtpdCB2OC42LjExRN9eGgAAAOpJREFUeJzd0j8LAXEcx/FTJgMxeg4Y
    PABKShmVB2CRBQ/AYrTecv8Hit3G4AGYLDYGgywUiyLx876ifuWKYzO8uu7X7/O5793vFCGE8ovP
    NypKAWvs0fymoIsq8jj6LpCKWpi+FBiGUcdN1/WctDbEUlXV8CNcwRYJrwkChEcEFgihhrNlWelH
    uIgDMoh6voLjOHFCW/RxRFMafQ4hCXp+A9M0ywQF00zcqXwfI+EOLti5E/kq0DQtS/DKFCWuM4zf
    TSE/OYIVeu49r5ByPyJljY8K2DggsLFtO/Zco6TN2omTSP78K/9xwR1s6a8J9mq0EQAAAABJRU5E
    rkJggg==
  }]
  set ::prdoc::ICONS(sub) [image create photo -data {
    iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABHNCSVQICAgIfAhkiAAAABt0RVh0
    U29mdHdhcmUAVGsgVG9vbGtpdCB2OC42LjExRN9eGgAAAOtJREFUeJzN0j8LAXEcx/FTJgMxeg4Y
    PABKShmVB2CRBQ/AYrTecv8Hit3G4AGYLDYGgywUiyLx875yumLwY/GrV9f9us+n7+/uFCGE8ouf
    wn9WYBhGHTdd13O+vSGWqqqGP5kgQHhEYIEQajhblpX++AiO48QJbdHHEU3pd2CaZpmgYJqJO5V0
    AeEOLti5E0kVaJqWJXhlihLXGcbeFKwC1tij+VLAwxGs0HPvOULKfYmUNR4FXVSRx/GlgAcHBDa2
    bce8PUra7J34EslnQFFamH71I7Eq2CIhXcAq4oAMot8UzCF8gtJHeOcOvb6vCcPvOHwAAAAASUVO
    RK5CYII=
  }]
  set ::prdoc::ICONS(ol) [image create photo -data {
    iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABHNCSVQICAgIfAhkiAAAABt0RVh0
    U29mdHdhcmUAVGsgVG9vbGtpdCB2OC42LjExRN9eGgAAAH5JREFUeJxj+P//PwMlGEIwMGwC4mWU
    GCCHbgAQHAXi/3jwEUIGHCFgwGFkA7YA8UMgjiHLC9QIxJlAvA+IHcl2ARAUAXEsuYHoAHUFE7mB
    +BaI1wJxyIAF4lQgPgTEVuQaoArES4HYmNxAFADiWiBOIDcQVwHxASB2pXsgAgCi6z5SCmiEmwAA
    AABJRU5ErkJggg==
  }]
  set ::prdoc::ICONS(ul) [image create photo -data {
    iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABHNCSVQICAgIfAhkiAAAABt0RVh0
    U29mdHdhcmUAVGsgVG9vbGtpdCB2OC42LjExRN9eGgAAAERJREFUeJxj+P//PwMlGEIwMKgAcRGI
    JteAO0AMYtyCSzAwHIWK4cJHkA24jcWAIwQMOIzuhUIgVibLC6OBOBqIQz8QAbRqN8QHP4iGAAAA
    AElFTkSuQmCC
  }]
  set ::prdoc::ICONS(li) [image create photo -data {
    iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABHNCSVQICAgIfAhkiAAAABt0RVh0
    U29mdHdhcmUAVGsgVG9vbGtpdCB2OC42LjExRN9eGgAAAGxJREFUeJxj+P//PwMlGEIwMKgAcRGI
    JteAO0AMYtyCSzAwHIWK4cJHkA24jcWAIwQMOIzuhUIgVibLCxQHIt0NAIJOBrBWEg0AAgEg7gfi
    f+Qa0ADEj4B4J7kGqAIxJxC3kWUAkkEj3gBkDABSGIidOzTlAgAAAABJRU5ErkJggg==
  }]
  set ::prdoc::ICONS(lili) [image create photo -data {
    iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABHNCSVQICAgIfAhkiAAAABt0RVh0
    U29mdHdhcmUAVGsgVG9vbGtpdCB2OC42LjExRN9eGgAAAIFJREFUeJxj+P//PwMlGEIwMKgAcRGI
    JteAO0AMYtyCSzAwHIWK4cJHkA24jcWAIwQMOIzuhUIgVibLCxQH4uA2AAjMgfguEBcA8Xog/gbE
    l4HYllgDHKCh/huIpwDxBCj/CqkGbEcSew5yCakGzEASuwLEf0g1oB9J7OIQMoAQBgCJ+mKAXvi8
    pwAAAABJRU5ErkJggg==
  }]
  set ::prdoc::ICONS(X) [image create photo -data {
    iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABHNCSVQICAgIfAhkiAAAABt0RVh0
    U29mdHdhcmUAVGsgVG9vbGtpdCB2OC42LjExRN9eGgAAAQBJREFUeJyl07ELQUEcB/BDSZFkY1NK
    8hcokyKLf4FFBskmm8HCxGDBZLHZlNHC6h+wyWCRxaAMnu/l1Nc5ryfD59W7u77vd3e/JyzLEv94
    PoQoQssgr+bDUKfxJqQ5wA1DsEj37UtC+GEPO0i8VaAWeGFLAXJxkOYjaiz+sQValIIrhYypwgVk
    jGeghTQp4A456EH16yFqAR7YUMgJ+ra3YAiJwYVCJj8FqJCWtpXCLxUEYAVrCjlAyMkZuGAGWYjC
    mUKmTgI6suvovaw1WNGuD0owN4QuKeAom0r/F2TZFbhBwxCQ06qQ1+zjgLbsOmUENdkPai4JA5p/
    6dleo1MP3Rjo1itTbeIAAAAASUVORK5CYII=
  }]
  set ::prdoc::ICONS(key_6) [image create photo -data {
    iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABHNCSVQICAgIfAhkiAAAABt0RVh0
    U29mdHdhcmUAVGsgVG9vbGtpdCB2OC42LjExRN9eGgAAAVlJREFUeJylkz9rg2AQxm2HfiajGMgQ
    iGTQkCFfwEGyhNI/s0M+gyJky5bB1dJsbtmCo22dHJxCCFGiJT71PahESUlKhBPe53h+nnfvcQC4
    W4Jei8XiwTCMN0VR8larhQsR8jz/ynHcfQWYTqfvVxhrIQjCUwVQVfW7kYRpmojjGIfDAavVCoPB
    oAn5+AXcMcNp0rIssCcIAriui6IosF6vm4CiquA0IYoittst0jRFt9slzbZtzGYzSJJUg5wFlL9D
    X/d9H5PJhKoZj8dn+3AWoGkaAZIkQZZl2O12dGagqwC6rpMhz3OMRiN0Oh2EYUhnWZYvA4bDIQGi
    KKo0x3FIY/CLgHa7jf1+T+X3ej3SPM8jAKvoL0BxmpjP52RgpS+XSxyPRxpjY9y1MX42R8kgm82G
    msgg/X6/2cSgArBr+d+rXO7DYwVgi1GKL2xRrjB/lfFcW6Zb4gd3q01ZG3lpWgAAAABJRU5ErkJg
    gg==
  }]
  set ::prdoc::ICONS(key_6_gold) [image create photo -data {
    iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABHNCSVQICAgIfAhkiAAAABt0RVh0
    U29mdHdhcmUAVGsgVG9vbGtpdCB2OC42LjExRN9eGgAAAatJREFUeJylk8tLAlEUxq1Ff5bjqPNQ
    s9TepmXaQ2lRPpGerqKBJAOtjUb0FNq0iqhWQdtqI5SZ2L9R4Ne915ySrIwW38zwzT2/e86552oA
    aP4j9igUCh2Kopy5XK4XWZbxi8qSJMUSiUS7Ckgmk+ctBDaIQMIqwO12v3oHRYwR0Z/xSQGrs0Z0
    WyU1YMYjYC1kgLNX9R7rgDaTyYRM3IA0UWxCwHNei0qew4nCs8Vhn4DKkZb5tzkOVguDVNUM6KI6
    ILuox3rUCM+AiPIhB7NJxkWKx9acHv12GXfbHMuQxjQF5JYMOE3y6LNJoGV1WmSUDrRwdNVSn3CK
    sL2X1hQwPSKw9O93OSz4jWRXiX3TNQGXgHm/wMDfAuh30CviKq1DcY+Ds0dib+ofr/CsD5n3dU0B
    StDATsNilnGT5eAbEkkJHCuJamdZ/zOA7kIbSRtW3NeyEs5TNW/QIeFyg28KqNYBkfGPI7ve1Kkl
    0b5Q74GUMzUsfjnG0udBCnlrQzNg/xikgFtk3mh/zSOzU1QBdCz/OspEQRVALwYxovSitBD4RHaP
    NFym/+gN5itINk+Ba6AAAAAASUVORK5CYII=
  }]
  set ::prdoc::ICONS(key_6_blue) [image create photo -data {
    iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABHNCSVQICAgIfAhkiAAAABt0RVh0
    U29mdHdhcmUAVGsgVG9vbGtpdCB2OC42LjExRN9eGgAAAVtJREFUeJylk11LAkEUhq2L/tq6Wuti
    YqG7KmukrRKFHyFdtNSVhBEVlYLSTVCBoklrnz/Dm75+SIFvMxM7NNii4sWz7Bz2POcc9owHgGca
    2KPf78+Vy+V7TdO+vF4vRvApSVLRsqxZLqhUKo9jJAoQSY4LdF3/VuMJhPNbAkokyj6eXwxhqVhC
    OFeETwk4kjdHMCPLMiLWHrK9FwGaQJPXmt1fWl2krppEolDBgHdAjVRgdnrwBVSO7PcjsrOL9E0b
    vgWFVTc7NhPTnGFB2x6alXagRDX2Tiubtz0ynosgaz9j5eKSkaw1RBkZ0zivI3Xdgl9V/xdk7p5g
    VBuMxNGpIFgubSPTfUBAj/HYWCM4JI7PENs/EGITCYJpE6qRdBUMRgmMah3xw5O/MeE3vgdXU6wL
    N0E4V0BofYOfye68cgFdy0lXmbDJBfRikECBXpQxEj9I9bxwmabhB7z2QTPjSaMEAAAAAElFTkSu
    QmCC
  }]
  set ::prdoc::ICONS(key_f) [image create photo -data {
    iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABHNCSVQICAgIfAhkiAAAABt0RVh0
    U29mdHdhcmUAVGsgVG9vbGtpdCB2OC42LjExRN9eGgAAAPBJREFUeJxj+P//PwMlGMK4uortzbGm
    HU82Bv96uMLuPwF87+FK+7L/DQxMcAPenGjbRYRGFPxgpV0x3ICnm0N/oyu4Ot/6v5Oh0H82Vqb/
    UiLs/7d1GKEbchtmAOPDFfYYNkzN1wTKMvzXlOP+XxQq///yXCt0Nf/gLkDXfAmoODdQDmxAToDc
    /+NTzbF6A6cBBSHyYM0wrCLNRZoBu3tM/gfZioM1hzlI/F9UqUuaASBcHaMENqAhQRlnTAwuA/6R
    YQByNNreIcOAW3ADQMmS1KT8aLltISIzATPGgxW2peCMQljz3QfL7UpQMhMlGACBaqBpK8tFfQAA
    AABJRU5ErkJggg==
  }]
  set ::prdoc::ICONS(key_g) [image create photo -data {
    iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABHNCSVQICAgIfAhkiAAAABt0RVh0
    U29mdHdhcmUAVGsgVG9vbGtpdCB2OC42LjExRN9eGgAAAXRJREFUeJxj+P//PwMlGExcvXqVbf6F
    Kzuq9x/5lbN973/8eN+9nB17yhoaGpjgBiy+dG0XYY2oOHfHnmK4AXUHjv5GlgybOO2/mJr6fxY2
    9v+yhkb/bdOz//NJSP73bW5HNuQ2zADGXCTNaWs2/efkF/jPzMLy3yg0/L+Ol89/JmZmoEqG/x7V
    9cgG/IO7ANl2t/JqsGJdX3+4mKKlNTYD/mM1wCopFazYLjMHLmYSEU28AU75xWDFBoEhcDEVW3vi
    DUhcuuo/Myvrf1YOjv/WKRn/jcMi/zMyMRFvAAi7llb+Z+XkBGsSVlT6r+7sCmZ71zURNiBp2Zr/
    vk1t/yOmzvwfv3DZ/+xte/7r+QWCDQidMBWnAf9gggmLVoCjjZGREex8EGbj5v7Pwcf3P23tZpzR
    eAfZZM+ahv+iKqpgb7Bz8/yX1NL5H9Tdj5oat+29BTcAlCxJTcrAPFEINwCUMXK37ysFZxTCmu8C
    bS9ByUyUYABUxIzu66ihjAAAAABJRU5ErkJggg==
  }]
  set ::prdoc::ICONS(B) [image create photo -data {
    iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABHNCSVQICAgIfAhkiAAAABt0RVh0
    U29mdHdhcmUAVGsgVG9vbGtpdCB2OC42LjExRN9eGgAAAKtJREFUeJxj+P//PwMlGMEAMnHgj0D8
    CIj3ArEbOQYg479AHETIAJBtoUg4CYjnIslfJ2TAZax+ZWA4i+QKZpIMAGkA4ptQ+ZuEXPACiMuR
    cBUQH4TK/QPiMEoCsYOYWPgJxHeh+DU0GpENWQ7ELKSGgRQQ70JSk0ROLDggqVlBjgHRxBqAnJBi
    gDgNiJuB+D2SmkRyYwGEjxIKRHT8DoqvAnErEPNijUZyMQBvmNXH/VE5DwAAAABJRU5ErkJggg==
  }]
  set ::prdoc::ICONS(C) [image create photo -data {
    iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABHNCSVQICAgIfAhkiAAAABt0RVh0
    U29mdHdhcmUAVGsgVG9vbGtpdCB2OC42LjExRN9eGgAAAOFJREFUeJyl0rELQVEUx/FbJBFvN5LB
    YLEa2I3KYDTZbGSxmGUymJRVJAsxsliURf4CRdlleb6vzvDy7iXPqU+9ut3fu/fco2zbVv8wLyiV
    QBcLTDDFDC0MUNAGUGH0cEENQdeahQ2eiHgCqBi2uCJtOFkOe+0VqDmcj9KHq4XQ9wRQZdm8+to4
    pZK6gJ0EFH9+BSojm28I+AmoSMDS1xxQTQkY+Q2oS8DYb0BWAs5fuu88YUo7ytRaQqqGzUF0EDcF
    OLN/wgMNRF1reQzf/66bxCjaOOCOo4y202TL2IN/vAB46ECoPgU0rQAAAABJRU5ErkJggg==
  }]
  set ::prdoc::ICONS(F) [image create photo -data {
    iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABHNCSVQICAgIfAhkiAAAABt0RVh0
    U29mdHdhcmUAVGsgVG9vbGtpdCB2OC42LjExRN9eGgAAAEVJREFUeJxj+P//PwMlGJXDwHAGiP8T
    wGfpZkAyEMdhwd7EGsBBaRhQbEAYEAeiYTdKY+EBXQ0QAWJeNMxN10AckQaQgwFutSl4apYVaQAA
    AABJRU5ErkJggg==
  }]
  set ::prdoc::ICONS(G) [image create photo -data {
    iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABHNCSVQICAgIfAhkiAAAABt0RVh0
    U29mdHdhcmUAVGsgVG9vbGtpdCB2OC42LjExRN9eGgAAAP5JREFUeJxj+P//PwMlGFOAgUEUiBuB
    +AIQvwPi70B8A4g3AXEgXgOAwAmInwPxfzx4HhAzYhgABKpA/Amq6B8QbwTiTCCOB+IZQPwDyZB0
    bAbsQFKQisVrHkjyV1EMAAI5IP4LldyLM8AYGGKg3hRCNyACyfQ6kmMBCIqRDIhFszUciMuxYGFk
    AwqRDIhCM2AXjtjQRDYgDEmiBs2AqUB8Bopf4zJADIh/QyXOIsczmmEzsRoAldyEJFmBRbMgEB/A
    Z4ACUkL6D/V7FhDHAXEPEL9BCwN1bEnZAoifEEjKIIOS8WUmkFPzgfgoED8D4p9QQ7cAcQYQ8+DN
    jaRiAFVnyV3ikwqEAAAAAElFTkSuQmCC
  }]
  set ::prdoc::ICONS(I) [image create photo -data {
    iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABHNCSVQICAgIfAhkiAAAABt0RVh0
    U29mdHdhcmUAVGsgVG9vbGtpdCB2OC42LjExRN9eGgAAAJ9JREFUeJxj+P//PwMlGLcEAwMfEJcA
    8TMgBgl8BuImIJYhygAkg5ZDDUghyQVIBlwD4m8gF5FsABBIAvE/IN5CchhADUiGOj+bXAPWQA1Q
    JicWWIH4AxBfJzcaHaG295FrQBfUAFdyDbgCxF+AmJ1kA4BAFmr7RoLpBIcBBVADckk2AAgYoakP
    xLEkyQAgSAOlOqhmEN4GxDFkBSKxGADeyoYQP4z2FQAAAABJRU5ErkJggg==
  }]
  set ::prdoc::ICONS(K) [image create photo -data {
    iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABHNCSVQICAgIfAhkiAAAABt0RVh0
    U29mdHdhcmUAVGsgVG9vbGtpdCB2OC42LjExRN9eGgAAAPVJREFUeJxj+P//PwMlGFOAgUEMiJWQ
    sCKSnAK6ODYDdIB4ExCDOCeB2AlJbhYQ/wPidUDsj9UAqMImqAG2aC7bB8QBeL0AVbwNiB8DMSOU
    bwTEq0BOJyYMOIH4KxBPhfLjgHgGSJzYQPSGOj8U6udIUmNhKhD/AuJbQLyCnGi8Dw2sSqhLfIk2
    AAi0oZqKgZgFiM8B8UMg5iXWgDKoAepQvikQ/wHiScQacBCI76CJTQDiv0BshdcAIJCDKpyLZgAf
    EH8HGQxiYzUACCyBeD3U+fuB2B0qzgzEqVCDQQInoNHMiW6AIloGkkMyQAkLZsWblEnBAHgBAoPq
    gqGiAAAAAElFTkSuQmCC
  }]
  set ::prdoc::ICONS(N) [image create photo -data {
    iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABHNCSVQICAgIfAhkiAAAABt0RVh0
    U29mdHdhcmUAVGsgVG9vbGtpdCB2OC42LjExRN9eGgAAAIpJREFUeJxj+P//PwMlGMFgYGgA4v9Q
    3IuhkIGBFUl+FiEDfgOxASUGgPBJIGaixAAQTiHXgH9Q+i0Qi5JjwBwk9jxyDFAD4mtIrnEg1QAF
    ILZD8soVIOYiyQCo2EIksSpyDBCFBiSI841kA6DiqViilyQDGIH4CNkGQOV0gPgX2QZA5bvwGkAu
    BgD3B7tFZOUXQQAAAABJRU5ErkJggg==
  }]
  set ::prdoc::ICONS(V) [image create photo -data {
    iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABHNCSVQICAgIfAhkiAAAABt0RVh0
    U29mdHdhcmUAVGsgVG9vbGtpdCB2OC42LjExRN9eGgAAAOJJREFUeJxj+P//PwMlGEIwMAQB8X8o
    3oNTMQPDIiR10cgGsAHxW6jEXyCWwqKZFYjfQdV8AWIeuAFQBbORTM/BYoA3kvxiFC9AFTggKTiM
    xYAFSPIe2AxgBOL7UAX/gFgezfkwL74EYhYMA6AKO5BsKUIS90QSn4ARC0gKtZAUnkQSn4skborT
    AKjii0iKVaDOfwPl38KaDtAMKEMyoBKI3ZH4tcQYIA3Ef6AaLqBFrypBA6CG7EfS9AVKH8OZlLEY
    kIJkAAxnkWIAHxB/Q9L8G4jFiDYAasgaJAM2482NlGAAL0sMYTwaDIcAAAAASUVORK5CYII=
  }]
  set ::prdoc::ICONS(collapse) [image create photo -data {
    R0lGODdhCQAJAIAAAAEBAf///ywAAAAACQAJAAACEISPoRvG614D80x5ZXyogwIAOw==
  }]
  set ::prdoc::ICONS(expand) [image create photo -data {
    R0lGODdhCQAJAIAAAAEBAf///ywAAAAACQAJAAACEYSPoRu28KCSDSJLc44s3lMAADs=
  }]
}

# ------------------------------------------------------------------------------
# Rendering section
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
proc ::prdoc::RenderImage { wid } {

  set count ""
  set idict [dict create]

  set res [$wid search -forwards -regexp -nocase -all -count count -nolinestop \
    {<img("[^"]*"|'[^']*'|[^'">])*>} 1.0 end]
  if {[llength $res] == 0 || [llength $count] == 0} { return }

  foreach rr [lreverse $res] cc [lreverse $count] {
    ::htmlTagAttr::img [$wid get $rr "$rr + $cc chars"] idict

    if {[dict exists $idict src]} {
      set iext [file extension [dict get $idict src]]
      set fnam "$::HP15(prgmdir)/[dict get $idict src]"

      if {[file isfile $fnam] && [string tolower $iext] in {".gif" ".png"}} {
        $wid image create $rr -image [image create photo -file $fnam] -padx 20
      } else {
        if {[dict exists $idict alt]} {
          set talt [dict get $idict alt]
        } {
          set talt [dict get $idict src]
        }
        if {[file isfile $fnam]} {
          append talt "\n([mc pdocu.previewfmt])"
        } else {
          append talt "\n([mc pdocu.noimagefile])"
        }
        $wid replace $rr "$rr + $cc chars" "\n$talt\n\n" tagnoimage
      }
    }
  }

}

# ------------------------------------------------------------------------------
proc ::prdoc::RenderPre { wid } {

  set ii 0

  set prelst [$wid search -all -regexp -nolinestop {<pre>} 0.0 end]
  foreach p1 $prelst {
    set p2 [$wid search -regexp -nolinestop {</pre>} $p1 end]

    foreach {tt fn} {em FnFixem i FnFixem strong FnFixstrong bold FnFixstrong} {
      set ttlst [$wid search -all -regexp -nolinestop "<$tt>(.*?)</$tt>" $p1 $p2]
      foreach t1 $ttlst {
        set t2 [$wid search -regexp -nolinestop "</$tt>" $t1 end]
        $wid tag add pretag$ii $t1 $t2
        $wid tag configure pretag$ii -font $fn
      }
      incr ii
    }
  }

}

# ------------------------------------------------------------------------------
proc ::prdoc::Render { wid } {

  variable TagStyle
  variable HTMLentities

# Step 1: Add or replace chars in widget text

# Padding for HP-15C CSS styles content
  set dd [$wid get 0.0 end]
  foreach tt [list KeyLabel fKeyLabel gKeyLabel fKey gKey] {
    lassign $TagStyle($tt) topen tclose topts
    set tpattern "($topen)(.*?)($tclose)"
    regsub -all -nocase $tpattern $dd {\1 \2 \3} dd
  }

# Replace individual tags and characters
  regsub -all -nocase "<br>" $dd "\n" dd
  regsub -all -nocase "<p>" $dd "\n" dd

# Replace HTML Entities
  set dd [string map $HTMLentities $dd]

# Format lists items
  set olcnt {}
# Start position of first list
  set trng [regexp -nocase -indices -inline {<ol("[^"]*"|'[^']*'|[^'">])*>|<ul>} $dd]
  while {[llength [lindex $trng 0]] > 0} {
    lassign [lindex $trng 0] p0 p1
    set p2 $p1
    set tt [string range $dd $p0 $p1]
    switch -regexp $tt {
      <ol.*> {
        set start 1
        ::html::extractParam $tt start start
        lappend olcnt ol $start
      }
      "<ul>" {
        lappend olcnt ul 0
      }
      "</ol>" -
      "</ul>" {
        set olcnt [lrange $olcnt 0 end-2]
      }
      "<li>" {
        switch [lindex $olcnt end-1] {
          "ol" {
            set dd [string replace $dd $p0 $p1 \
              "<li>[format {%2d. } [lindex $olcnt end]]"]
            lset olcnt end [expr [lindex $olcnt end] + 1]
          }
          "ul" {
            set dd [string replace $dd $p0 $p1 "<li>\u2022 "]
          }
        }
# WA: Prevent formatting from starting at left border
        regsub -all -nocase {(\n)(<span)} $dd {\1 \2} dd
      }
    }
    set trng [regexp -nocase -indices -inline -start $p2 \
      {<ol("[^"]*"|'[^']*'|[^'">])*>|</*[ou]l>|<li>} $dd]
  }

# Replace render widget content with updated text
  $wid replace 0.0 end $dd

# Step 2: Add and configure tags

# HTML and HP-15C tags
  foreach tt [array names TagStyle] {
    lassign $TagStyle($tt) topen tclose topts
    set tpattern "$topen.*?$tclose"
    set count {}
    set res [$wid search -forwards -regexp -nocase -all -count count -nolinestop \
      $tpattern 1.0 end]
    if {[llength $res] > 0 && [llength $count] > 0} {
      foreach rr $res cc $count {
        $wid tag add tag$tt $rr "$rr + $cc chars"
      }
    }
    $wid tag configure tag$tt {*}$topts
  }

# Text with bold AND italic and code with additional styles
  set tranges [concat [$wid tag ranges tagcode] [$wid tag ranges tagem] \
    [$wid tag ranges tagstrong] [$wid tag ranges tagbold]]
  foreach {tbeg tend} $tranges {
    set tnames [$wid tag names $tbeg]
# Do not over specify...
    if {[lsearch -regexp $tnames {tag(pre|docemstrong|codeemstrong)}] < 0} {
      lassign {"doc" "" ""} tf te ts
      if {[lsearch -regexp $tnames {tagcode}] > -1} { set tf "code" }
      if {[lsearch -regexp $tnames {tagem|tagi}] > -1} { set te "em" }
      if {[lsearch -regexp $tnames {tagstrong|tagbold}] > -1} { set ts "strong" }
      if {"$te$ts" ne ""} {
        $wid tag add tag$tf$te$ts $tbeg $tend
      }
    }
  }
  $wid tag configure tagdocemstrong -font FnPrDocemstrong
  $wid tag configure tagcodeem -font FnCodeem
  $wid tag configure tagcodestrong -font FnCodestrong
  $wid tag configure tagcodeemstrong -font FnCodeemstrong
  $wid tag raise tagdocemstrong
  $wid tag raise tagcodeemstrong

# Indent lists
  array set indid {}
  set indlevel 0
  set indincr [font measure TkTextFont " 1."]
  set indb [font measure TkTextFont "\u2022"]
  set lipos {}
  set res [$wid search -forwards -regexp -nocase -all -nolinestop -count count \
      {<ol("[^"]*"|'[^']*'|[^'">])*>|</*[ou]l>|</*li>} 1.0 end]
  if {[llength $res] > 0 && [llength $count] > 0} {
    foreach rr $res cc $count {
      set tnam [$wid get $rr "$rr + $cc chars"]
      switch -regexp $tnam {
        <ol.*> -
        "<ul>" {
          incr indlevel
          incr indid($indlevel)
          set tagInd tagInd$indlevel$indid($indlevel)
          set indl [expr $indlevel*$indincr*1.5]
          $wid tag configure $tagInd -lmargin1 ${indl}p
          if {$tnam eq "<ol>"} {
            set lm2 $indincr
          } else {
            set lm2 $indb
          }
          $wid tag configure $tagInd -lmargin2 [expr $indl + $lm2]p
        }
        "</ol>" -
        "</ul>" {
          incr indlevel -1
        }
        "<li>" {
          lappend lipos $rr
        }
        "</li>" {
          catch {
            set tagInd tagInd$indlevel$indid($indlevel)
            $wid tag add $tagInd [lindex $lipos end] "$rr + $cc chars"

# set lmargin1 to lmargin2 after a newline in li-element
            set litxt [$wid get [lindex $lipos end] "$rr + $cc chars"]
            if {[string last "<li>" $litxt] == 0 && [string first "\n" $litxt] > 0} {
              set nl [$wid search -forwards "\n" [lindex $lipos end] "$rr + $cc chars"]
              $wid tag add $tagInd\2 "$nl + 1 chars" "$rr + $cc chars"
              $wid tag configure $tagInd\2 -lmargin1 [expr $indl + $lm2]p
            }
          }
          set lipos [lrange $lipos 0 end-1]
        }
      }
    }
  }

# Render margins
  set bgcol [$wid cget -background]
  $wid tag configure tagpre -lmargin1 20 -lmargincolor $bgcol \
    -rmargin 20 -rmargincolor $bgcol
  $wid tag configure tagnoimage -lmargincolor $bgcol -rmargincolor $bgcol

# Render images
  ::prdoc::RenderImage $wid

# Render pre-formatted code
  ::prdoc::RenderPre $wid

# Make links clickable
  set res [$wid search -forwards -regexp -nocase -all -count count \
    "<a href.*</a>" 1.0 end]
  if {[llength $res] > 0 && [llength $count] > 0} {
    set ii 0
    foreach rr $res cc $count {
      regexp -nocase {<a href="([^"]+)".*>} [$wid get $rr "$rr + $cc chars"] ign url
      if {[info exists url] && $url != ""} {
        $wid tag add url$ii $rr "$rr + $cc chars"
        $wid tag bind url$ii <Button-1> "url_open $url"
        $wid tag bind url$ii <Enter> "$wid configure -cursor hand2"
        $wid tag bind url$ii <Leave> "$wid configure -cursor arrow"
      }
      incr ii
    }
  }

# Hide tags
  set res [$wid search -forwards -regexp -nocase -all -count count \
    "</*\[\[:alnum:]]+\[^>]*>" 1.0 end]
  foreach rr $res cc $count {
    $wid tag add tagtag $rr "$rr + $cc chars"
  }
  $wid tag configure tagtag -elide true

}

# ------------------------------------------------------------------------------
# Search/Replace section
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
proc ::prdoc::Search {} {

  variable STATUS

  set wid .pdocu.description.edit.txt
  if {[winfo ismapped $wid]} {
    ::history::add STATUS(searchhist) $STATUS(search)
    ::textSearchReplace::findSelect $wid $STATUS(search)
  }

}

# ------------------------------------------------------------------------------
proc ::prdoc::MarkAll {} {

  variable STATUS

  set wid .pdocu.description.edit.txt
  if {[winfo ismapped $wid]} {
    ::history::add STATUS(searchhist) $STATUS(search)
    ::textSearchReplace::markAll $wid $STATUS(search)
  }

}

# ------------------------------------------------------------------------------
proc ::prdoc::Replace { {all 0} } {

  variable STATUS

  set wid .pdocu.description.edit.txt
  if {[winfo ismapped $wid]} {
    ::history::add STATUS(searchhist) $STATUS(search)
    ::history::add STATUS(replacehist) $STATUS(replace)
    if {$all} {
      ::textSearchReplace::replaceAll $wid $STATUS(search) $STATUS(replace)
    } elseif {[llength [$wid tag ranges sel]] == 0} {
      ::prdoc::Search
    } else {
      ::textSearchReplace::replace $wid $STATUS(search) $STATUS(replace)
      ::prdoc::Search
    }
    ::prdoc::HighlightTags $wid
  }

}

# ------------------------------------------------------------------------------
proc ::prdoc::SearchHist { wid } {

  $wid configure -values [::history::get ::prdoc::STATUS(searchhist)]

}

# ------------------------------------------------------------------------------
proc ::prdoc::ReplaceHist { wid } {

  $wid configure -values [::history::get ::prdoc::STATUS(replacehist)]

}

# ------------------------------------------------------------------------------
# Editing section
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
proc ::prdoc::InsertText { wid txt } {

  switch [winfo class $wid] {
    Text {
      set sel [$wid tag ranges sel]
      if {[llength $sel] == 0} {
        $wid insert [$wid index insert] $txt
      } else {
        set mark [$wid get [lindex $sel 0] [lindex $sel 1]]
        $wid replace [lindex $sel 0] [lindex $sel 1] "$txt"
      }
      HighlightTags $wid
    }
    TEntry -
    TCombobox {
      set ipos [$wid index insert]
      if {[$wid selection present]} {
        set ipos [$wid index sel.first]
        $wid delete [$wid index sel.first] [$wid index sel.last]
      }
      $wid insert $ipos "$txt"
    }
  }
  focus $wid

}

# ------------------------------------------------------------------------------
proc ::prdoc::AddTag { wid tag } {

  variable TagStyle

  lassign $TagStyle($tag) topen tclose ign
  set sel [$wid tag ranges sel]
  if {[llength $sel] == 0} {
    $wid insert [$wid index insert] "$topen$tclose"
    $wid mark set insert "[$wid index insert] - [string length $tclose]c"
  } else {
    set mark [$wid get [lindex $sel 0] [lindex $sel 1]]
# If selection is tagged with the same tag, untag selection
    if {[regexp "^$topen\(.*)$tclose$" $mark mv smv1]} {
      $wid replace [lindex $sel 0] [lindex $sel 1] $smv1
    } else {
      set str [$wid get sel.first sel.last]
      set repl $topen
      switch $tag {
        "a" {
          set url ""
          regexp -nocase "^https*://.*" $str url
          set repl "<a href=\"$url\">$str"
        }
        "lili" {
          append repl [regsub -all {\n} $str "$tclose\n$topen"]
        }
        default {
          append repl $str
        }
      }
      append repl $tclose
      $wid replace [lindex $sel 0] [lindex $sel 1] $repl
      $wid mark set insert "[lindex $sel 1] + [string length $topen]c"
    }
  }
  HighlightTags $wid
  ::prdoc::ResetModified $wid
  focus $wid

}

# ------------------------------------------------------------------------------
proc ::prdoc::HighlightTags { wid } {

  variable CONF

  $wid tag delete tagtag
  if {$CONF(taghighlight)} {
    set count {}
    set res [$wid search -forwards -regexp -nocase -all -count count \
      "</*\[\[:alnum:]]+\[^>]*>" 1.0 end]
    foreach rr $res cc $count {
      $wid tag add tagtag $rr "$rr + $cc chars"
    }
    $wid tag configure tagtag -foreground $CONF(tagcolour)
    if {$CONF(tagbold)} {
      $wid tag configure tagtag -font FnPrDocstrong
    }
  } else {
    $wid tag configure tagtag -foreground black -font TkTextFont
  }

# Make the selection the tag with the highest priority
  $wid tag raise sel

}

# ------------------------------------------------------------------------------
# Control section
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
proc ::prdoc::Analyse { prgm } {

  variable MARKS
  array set MARKS { L {} R {} F {} }

  set aregs {}
  set altmp {}
  set nltmp {}

# Scan the program for Labels, Registers and Flags
  foreach pl $prgm {
    if {[regexp {4[45]_([1234]0_)*(48_)*([0-9])$} $pl \
      step oper dec reg]} {
      if {$dec ne ""} {incr reg 10}
      lappend MARKS(R) $reg
    } elseif {[regexp {49|43_49$} $pl step lbl]} {
      lappend MARKS(R) 2 3 4 5 6 7
    } elseif {[regexp {4[45]_([1234]0_)*24$} $pl step]} {
      lappend aregs "(i)"
    } elseif {[regexp {4[45]_([1234]0_)*25$} $pl step]} {
      lappend aregs "I"
    } elseif {[regexp {[23]2_1([1-5])$} $pl step lbl]} {
      lappend altmp -$lbl
    } elseif {[regexp {[23]2_(48_)*([0-9])$} $pl step dec lbl]} {
      if {$dec ne ""} {incr lbl 10}
      lappend nltmp $lbl
    } elseif {[regexp {42_21_(48_)*([0-9])$} $pl step dec lbl]} {
      if {$dec ne ""} {incr lbl 10}
      lappend nltmp $lbl
    } elseif {[regexp {42_21_1([1-5])$} $pl step lbl]} {
      lappend altmp -$lbl
    }
  }
  set MARKS(L) [concat \
    [lsort -unique -integer -decreasing $altmp] [lsort -unique -integer $nltmp]]

  set MARKS(R) [lsort -unique -integer $MARKS(R)]
  lappend MARKS(R) {*}[join [lsort -unique -dictionary $aregs]]

  foreach pl $prgm {
    if {[regexp {43_[456]_([0-9])} $pl ign flag]} {
      lappend MARKS(F) $flag
    }
  }
  set MARKS(F) [lsort -unique -integer $MARKS(F)]

}

# ------------------------------------------------------------------------------
proc ::prdoc::SaveDesc {} {

  variable DESC
  variable DESC_T

  foreach nn [array names DESC_T] {
    set DESC($nn) [string trim $DESC_T($nn)]
  }
  set DESC(D) \
    [regsub -all { +\n} [.pdocu.description.edit.txt get 0.0 end] "\n"]
  set DESC(D) [regsub {\n*$} $DESC(D) ""]

}

# ------------------------------------------------------------------------------
proc ::prdoc::Return { wid } {

  if {[winfo class $wid] ne "Text"} {
    Act yes
  }

}

# ------------------------------------------------------------------------------
proc ::prdoc::Act { action }  {

  variable geomRE
  variable DocuChanged
  variable prevpos

  set rc true

  if {![winfo exists .pdocu]} {return $rc}

  regexp $geomRE [winfo geometry .pdocu] all w1xh1 w1 h1 xoff x1 yoff y1
  set prevpos $xoff$x1$yoff$y1

  if {$DocuChanged && $action ne "yes"} {
    wm deiconify .pdocu
    focus .pdocu
    set action [tk_messageBox -parent .pdocu -icon question -type yesnocancel \
      -default yes -title [mc menu.prgmdocu] -message [mc pdocu.changed]]
  }

  switch $action {
    "yes" {
      SaveDesc
      destroy .pdocu
    }
    "no" {
      destroy .pdocu
    }
    "cancel" {
      wm deiconify .pdocu
      focus .pdocu
      set rc false
    }
  }

  return $rc

}

# ------------------------------------------------------------------------------
proc ::prdoc::Purge { prgm } {

  variable DESC
  variable MARKS

  Analyse $prgm
  foreach pd [array names DESC -glob {[LRF]*}] {
    set mm [string index $pd 0]
    if {[lsearch $MARKS($mm) [string range $pd 1 end]] < 0} {
      array unset DESC $pd
    }
  }

}

# ------------------------------------------------------------------------------
proc ::prdoc::Changed { wid {n1 ""} {n2 ""} {op ""} } {

  variable DocuChanged

  if {!$DocuChanged} {
    set DocuChanged 1
    set tlw [winfo toplevel $wid]
    wm title $tlw "[wm title $tlw] *"
  }

}

# ------------------------------------------------------------------------------
proc ::prdoc::Discard {}  {

  variable DocuChanged
  set rc true

  if {![winfo exists .pdocu] || !$DocuChanged} {return $rc}

  wm deiconify .pdocu
  focus .pdocu
  set answer [tk_messageBox -parent .pdocu -icon question -type yesno \
    -default yes -title [mc menu.prgmdocu] -message [mc pdocu.discard]]
  if {$answer eq "no"} {
    set rc false
  } else {
    set DocuChanged false
  }

  return $rc

}

# ------------------------------------------------------------------------------
proc ::prdoc::Modified { wid } {

  if {[$wid edit modified]} {
    HighlightTags $wid
    Changed $wid
  }

}

# ------------------------------------------------------------------------------
proc ::prdoc::ResetModified { wid } {

  $wid edit modified 0

}

# ------------------------------------------------------------------------------
proc ::prdoc::SetMode { mode } {

  variable CONF

  if {$mode eq "render"} {
    set wid .pdocu.description.render

    $wid.txt configure -state normal
    $wid.txt replace 0.0 end [.pdocu.description.edit.txt get 0.0 end]
    prdoc::Render $wid.txt
    $wid.txt configure -state disabled

    bind .pdocu <F6> "::prdoc::SetMode edit"
    raise $wid
    focus .pdocu
  } else {
    set wid .pdocu.description.edit
    if {$CONF(taghighlight)} "HighlightTags $wid.txt"

    bind .pdocu <F6> "::prdoc::SetMode render"
    raise $wid
    focus $wid.txt
  }

}

# ------------------------------------------------------------------------------
# UI section
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
proc ::prdoc::TagsMenu { wid } {

  variable CONF
  variable ICONS

  if {[winfo exists .tam]} {destroy .tam}
  menu .tam

  .tam add command -label "[mc gen.bold]" -command "::prdoc::AddTag $wid strong"
  .tam add command -label "[mc gen.italic]" -command "::prdoc::AddTag $wid em"
  .tam add command -label "[mc gen.code]" -command "::prdoc::AddTag $wid code"
  .tam add command -label "[mc gen.preformatted]" -command "::prdoc::AddTag $wid pre"
  .tam add separator
  .tam add command -label "[mc gen.supscript]" -command "::prdoc::AddTag $wid sup"
  .tam add command -label "[mc gen.subscript]" -command "::prdoc::AddTag $wid sub"
  .tam add separator
  .tam add command -label "[mc gen.unorderedlist]" -command "::prdoc::AddTag $wid ul"
  .tam add command -label "[mc gen.orderedlist]" -command "::prdoc::AddTag $wid ol"
  .tam add command -label "[mc gen.listitem]" -command "::prdoc::AddTag $wid li"
  .tam add command -label "[mc gen.multipleitems]" -command "::prdoc::AddTag $wid lili"
  .tam add separator
  .tam add command -label "[mc gen.regs]" -command "::prdoc::AddTag $wid register"
  .tam add command -label "[mc gen.primaryfunc]" -command "::prdoc::AddTag $wid KeyLabel"
  .tam add command -label "[mc gen.goldfunc]" -command "::prdoc::AddTag $wid fKeyLabel"
  .tam add command -label "[mc gen.bluefunc]" -command "::prdoc::AddTag $wid gKeyLabel"
  .tam add command -label "f-[mc gen.key]" -command "::prdoc::AddTag $wid fKey"
  .tam add command -label "g-[mc gen.key]" -command "::prdoc::AddTag $wid gKey"

  if {$CONF(tagmenuicons)} {
    set idx 0
    foreach img [list [mc gen.boldchar] [mc gen.italicchar] code pre sep \
      sup sub sep ul ol li lili sep X key_6 key_6_gold key_6_blue key_f key_g] {
      if {$img ne "sep"} {
        .tam entryconfigure $idx -image $ICONS($img) -compound left
      }
      incr idx
    }
  }

  tk_popup .tam [winfo pointerx .] [winfo pointery .]

}

# ------------------------------------------------------------------------------
proc ::prdoc::SymbolsMenu { mname cmd } {

  variable Symbols
  variable CONF

  if {[winfo exists $mname]} {return}
  menu $mname

  foreach {nn bb} [list greek 12 math 10 supersub 10 arrows 6 moresyms 8] {
    set mm $mname.$nn
    menu $mm
    $mname add cascade -label [mc gen.$nn] -menu $mm
    set ii 0
    foreach {hent ucode} $Symbols($nn) {
      if {$CONF(unicodesyms) && !($hent in [list "&lt;" "&gt;"])} {
        set hent $ucode
      }
      $mm add command -label $ucode -command "$cmd \"$hent\""
      if {$ii % $bb == 0} { $mm entryconfigure $ii -columnbreak 1 }
      incr ii
    }
  }
  $mname.supersub configure -font FnPrSupsub

}

# ------------------------------------------------------------------------------
proc ::prdoc::EntryMenuPost { mname wid x y } {

  set ::prdoc::EntryMenuTarget $wid
  tk_popup $mname $x $y

}

# ------------------------------------------------------------------------------
proc ::prdoc::EntryMenuInvoke { val } {

  ::prdoc::InsertText $::prdoc::EntryMenuTarget $val

}

# ------------------------------------------------------------------------------
proc ::prdoc::TextMenuInvoke { val } {

  ::prdoc::InsertText .pdocu.description.edit.txt $val

}

# ------------------------------------------------------------------------------
proc ::prdoc::DrawMarks {} {

  variable LAYOUT
  variable CONF
  variable MARKS

  set lrf [expr \
   [llength $MARKS(L)]+[llength $MARKS(R)]+[llength $MARKS(F)]]
  set mmax [expr max([llength $MARKS(L)], [llength $MARKS(R)] ,[llength $MARKS(F)])]
  if {[winfo screenheight .] < 801 || $lrf > 30 || $mmax > 10} {
    set colcnt 3.0
    set ewid 30
  } else {
    set colcnt 2.0
    set ewid 40
  }

  set heightsav [winfo height .pdocu]

  set fpm .pdocu.marks
  set redraw [winfo exists $fpm]
  catch {destroy $fpm}

# Tabbed?
  if {$CONF(ShowResTab)} {
    ttk::notebook $fpm -padding [list 0 6 0 0]
  } else {
    ttk::frame $fpm
  }

  ::prdoc::SymbolsMenu .pdocu.marks.symbols ::prdoc::EntryMenuInvoke

  set row 1
  foreach {nam idx txt} {lbl L labels regs R regs flags F flags} {
    if {$CONF(ShowResTab)} {
      set fnam $fpm.$nam
    } else {
      ttk::labelframe $fpm.$nam -relief groove -borderwidth 2 -text " [mc gen.$txt] "
      grid columnconfigure $fpm.$nam 0 -weight 1
      set fnam $fpm.$nam.if
    }
    ttk::frame $fnam

    set rr 0
    set cc 0
    foreach ll $MARKS($idx) {
      ttk::label $fnam.label$ll -text "[format_mark $ll] " -width 3 -anchor e
      ttk::entry $fnam.value$ll -width $ewid -textvariable ::prdoc::DESC_T($idx$ll)
      grid $fnam.label$ll -row $rr -column $cc -sticky e -pady 1
      grid $fnam.value$ll -row $rr -column [expr $cc+1] -sticky we -pady 1
      bind $fnam.value$ll <<B3>> "::prdoc::EntryMenuPost .pdocu.marks.symbols %W %X %Y"
      incr rr
      if {$rr > int(ceil([llength $MARKS($idx)]/$colcnt))-1} {
        set rr 0
        incr cc 2
      }
    }
    if {[llength $MARKS($idx)] == 0} {
      ttk::label $fnam.nolabels -text "[mc pdocu.no$txt]" -anchor w -justify left
      grid $fnam.nolabels -row 0 -column 0 -padx 3 -pady 1 -sticky w
    }
    if {[llength $MARKS($idx)] == 1 || $colcnt == 1} {
      grid columnconfigure $fnam {1} -weight 2
    } else {
      for {set ii 1} {$ii < $colcnt*2} {incr ii 2} {
        grid columnconfigure $fnam $ii -weight 2
      }
    }
    grid $fnam -row 0 -column 0 -padx 7 -pady 5 -sticky nwse

  # Lay out marks
    if {$CONF(ShowResTab)} {
      $fnam configure -padding $LAYOUT(tabpad)
      $fpm add $fnam -text " [mc gen.$txt] " -sticky nsew
    } else {
      grid $fpm.$nam -row $row -column 0 -sticky nsew
    }
    incr row
  }

  grid columnconfigure $fpm 0 -weight 1

  if {$redraw} {
    update
    set heightnew [expr max(int(2.5*[winfo height $fpm]), $heightsav)]
    wm geometry .pdocu [winfo width .pdocu]x$heightnew
  }

  return $fpm

}

# ------------------------------------------------------------------------------
proc ::prdoc::ShowMarks { toggle wid } {

  variable STATUS
  variable ICONS

  set heightsav [winfo height .pdocu]

  if {$toggle} {
    set STATUS(showresources) [expr !$STATUS(showresources)]
  }

  if {$STATUS(showresources)} {
    if {![winfo exists .pdocu.marks]} {DrawMarks}
    $wid configure -image $ICONS(collapse)
    grid .pdocu.marks -row 1 -column 0 -padx 3 -sticky nsew
  } else {
    catch {grid remove .pdocu.marks}
    $wid configure -image $ICONS(expand)
    focus .pdocu.description.edit.txt
  }

  if {$toggle} {
    wm geometry .pdocu [winfo width .pdocu]x$heightsav
  }

}

# ------------------------------------------------------------------------------
proc ::prdoc::ToggleSearchWin { wlbl } {

  variable CONF
  variable STATUS
  variable ICONS

  set wid .pdocu.description.edit.srf
  set tl [winfo toplevel $wid]

  set heightsav [winfo height $tl]
  if {[winfo ismapped $wid]} {
    catch {grid remove $wid}
    $wlbl configure -image $ICONS(expand)
    focus .pdocu.description.edit.txt
  } else {
    grid $wid
    $wlbl configure -image $ICONS(collapse)
    set twid .pdocu.description.edit.txt
    if {[$twid tag ranges sel] ne ""} {
      set STATUS(search) [$twid get {*}[$twid tag ranges sel]]
    }
    ::textSearchReplace::setCase $STATUS(case)
    ::textSearchReplace::setDirection $STATUS(searchdir)
    ::textSearchReplace::setMarkColour $CONF(markcolour)
    ::textSearchReplace::setRegexp $STATUS(regexp)
    focus $wid.searchstr
  }

  wm geometry $tl [winfo width $tl]x$heightsav

}

# ------------------------------------------------------------------------------
proc ::prdoc::Draw { {geom ""} } {

  variable CONF
  variable STATUS
  variable MODKEY
  variable ADDTAG_BINDS
  variable ADDCHAR_BINDS
  variable LAYOUT
  variable ICONS
  variable DESC_T
  variable DocuChanged
  variable geomRE

  if {[winfo exists .pdocu]} {
    wm deiconify .pdocu
  } else {

    set dwid [expr int([winfo screenwidth .]*4.2/[font measure "TkTextFont" "1234567890"])]
# WA-macOS: Buttons are rendered much wider than on Windows and Linux
    if {$::tcl_platform(os) eq "Darwin"} { incr dwid 5 }

    if {[winfo screenheight .] > 800 || $CONF(ShowResTab)} {
      set dhei 25
    } else {
      set dhei 10
    }
    if {!$STATUS(showresources)} { incr dhei 5 }

    toplevel .pdocu
    wm attributes .pdocu -alpha 0.0

# Program info
    set fpd .pdocu.description
    ttk::labelframe $fpd -relief groove -borderwidth 2 -text " [mc pdocu.description] "
    ttk::label $fpd.title_lbl -text [mc pdocu.prgmtitle] -anchor w
    ttk::entry $fpd.title -textvariable ::prdoc::DESC_T(T)
    ttk::label $fpd.usage_lbl -text [mc pdocu.usage] -anchor w
    grid $fpd.title_lbl -row 0 -column 0 -padx 10 -sticky w
    grid $fpd.title -row 1 -column 0 -padx 10 -sticky we
    grid $fpd.usage_lbl -row 2 -column 0 -padx 10 -sticky w

# Edit frame
    set efrm $fpd.edit
    ttk::frame $efrm

    ttk::label $efrm.srshow -image $ICONS(expand) \
      -text "[mc gen.search]/[mc gen.replace]" -compound left

    text $efrm.txt -width $dwid -height $dhei -font TkTextFont -wrap word \
      -undo true -yscrollcommand [list $efrm.ysb set] -padx 2
    $efrm.txt configure -inactiveselectbackground [$efrm.txt cget -selectbackground]
    ttk::scrollbar $efrm.ysb -orient vertical -command [list $efrm.txt yview]

# Search and replace frame
    set srf $efrm.srf
    ttk::frame $srf

    ttk::combobox $srf.searchstr -textvariable ::prdoc::STATUS(search) -justify left \
      -height 15 -postcommand "::prdoc::SearchHist $srf.searchstr"
    ttk::button $srf.search -text [mc gen.search] -command ::prdoc::Search
    ttk::button $srf.markall -text [mc prdoc.markall] -command ::prdoc::MarkAll
    ttk::combobox $srf.replacestr -textvariable ::prdoc::STATUS(replace) -justify left \
      -height 15 -postcommand "::prdoc::ReplaceHist $srf.replacestr"
    ttk::button $srf.replace -text [mc gen.replace] -command ::prdoc::Replace
    ttk::button $srf.replaceall -text [mc gen.replaceall] \
       -command "::prdoc::Replace true"
    ttk::radiobutton $srf.fwd -text [mc gen.forwards] -value forward \
      -variable ::prdoc::STATUS(searchdir) \
      -command {::textSearchReplace::setDirection forward}
    ttk::radiobutton $srf.bwd -text [mc gen.backwards] -value backward \
      -variable ::prdoc::STATUS(searchdir) \
      -command {::textSearchReplace::setDirection backward}
    ttk::checkbutton $srf.case -text [mc gen.case] \
      -variable ::prdoc::STATUS(case) \
      -command {::textSearchReplace::setCase {*}$::prdoc::STATUS(case)}
    ttk::checkbutton $srf.regexp -text [mc gen.regexp] \
      -variable ::prdoc::STATUS(regexp) \
      -command {::textSearchReplace::setRegexp {*}$::prdoc::STATUS(regexp)}

# Symbols popup menu and bindings for search/replace
    ::prdoc::SymbolsMenu $srf.symbols ::prdoc::EntryMenuInvoke

    bind $efrm.srshow <Button-1> "::prdoc::ToggleSearchWin %W"
    bind $efrm.txt <$MODKEY(ctrl)-f> "::prdoc::ToggleSearchWin $efrm.srshow"
    bind $srf.searchstr <<B3>> "::prdoc::EntryMenuPost $srf.symbols %W %X %Y"
    bind $srf.searchstr <$MODKEY(ctrl)-f> "::prdoc::ToggleSearchWin $efrm.srshow"
    bind $srf.replacestr <<B3>> "::prdoc::EntryMenuPost $srf.symbols %W %X %Y"
    bind $srf.replacestr <$MODKEY(ctrl)-f> "::prdoc::ToggleSearchWin $efrm.srshow"

    grid $srf.searchstr -row 1 -column 0 -sticky nswe
    grid $srf.search -row 1 -column 1 -sticky nswe -padx 5
    grid $srf.markall -row 1 -column 2 -sticky nswe
    grid $srf.fwd -row 1 -column 3 -sticky nswe -padx 5
    grid $srf.case -row 1 -column 4 -sticky nswe

    grid $srf.replacestr -row 3 -column 0 -sticky nswe
    grid $srf.replace -row 3 -column 1 -sticky nswe -padx 5
    grid $srf.replaceall -row 3 -column 2 -sticky nswe
    grid $srf.bwd -row 3 -column 3 -sticky nswe -padx 5
    grid $srf.regexp -row 3 -column 4 -sticky nw

    grid rowconfigure $srf 2 -minsize 2
    grid columnconfigure $srf 0 -weight 1
    grid columnconfigure $srf 4 -minsize 10
    grid $srf -row 1 -column 0 -sticky we -columnspan 2 -pady 2
    grid remove $srf

# Edit text field and scrollbar
    grid $efrm.srshow -row 0 -column 0 -sticky nw
    grid $efrm.txt -row 2 -column 0 -sticky nwse -columnspan 2
    grid $efrm.ysb -row 2 -column 2 -sticky ns

    ttk::frame $efrm.tags
    ttk::button $efrm.tags.bold -text [mc gen.boldchar] -style strong.TButton \
      -command "::prdoc::AddTag $efrm.txt strong"
    ttk::button $efrm.tags.italic -text [mc gen.italicchar] -style em.TButton \
      -command "::prdoc::AddTag $efrm.txt em"
    ttk::button $efrm.tags.pre -text "pre" -style pre.TButton \
      -command "::prdoc::AddTag $efrm.txt pre"
    ttk::button $efrm.tags.code -text "code" -style pre.TButton \
      -command "::prdoc::AddTag $efrm.txt code"
    ttk::label $efrm.tags.sep1 -text " "

    ttk::button $efrm.tags.sup -text "sup" -style tag.TButton \
      -command "::prdoc::AddTag $efrm.txt sup"
    ttk::button $efrm.tags.sub -text "sub" -style tag.TButton \
      -command "::prdoc::AddTag $efrm.txt sub"
    ttk::label $efrm.tags.sep2 -text " "

    ttk::button $efrm.tags.ul -text "ul" -style tag.TButton \
      -command "::prdoc::AddTag $efrm.txt ul"
    ttk::button $efrm.tags.ol -text "ol" -style tag.TButton \
      -command "::prdoc::AddTag $efrm.txt ol"
    ttk::button $efrm.tags.li -text "li" -style tag.TButton \
      -command "::prdoc::AddTag $efrm.txt li"
    ttk::button $efrm.tags.lili -text "li\u2026li" -style tag.TButton \
      -command "::prdoc::AddTag $efrm.txt lili"
    ttk::label $efrm.tags.sep3 -text " "

    ttk::button $efrm.tags.reg -text "X" -style reg.TButton \
      -command "::prdoc::AddTag $efrm.txt register"
    ttk::button $efrm.tags.keylbl -text "123" -style strong.TButton \
      -width 4 -command "::prdoc::AddTag $efrm.txt KeyLabel"
    ttk::button $efrm.tags.fkeylbl -text "FFF" -style gold.TButton \
      -command "::prdoc::AddTag $efrm.txt fKeyLabel"
    ttk::button $efrm.tags.gkeylbl -text "GGG" -style blue.TButton \
      -command "::prdoc::AddTag $efrm.txt gKeyLabel"
    ttk::button $efrm.tags.f -text "f" -style fkey.TButton \
      -command "::prdoc::AddTag $efrm.txt fKey"
    ttk::button $efrm.tags.g -text "g" -style gkey.TButton \
      -command "::prdoc::AddTag $efrm.txt gKey"
    ttk::label $efrm.tags.sep4 -text " "
    ttk::menubutton $efrm.tags.entities -text [mc gen.characters] \
      -menu $efrm.tags.entities.symbols
    ::prdoc::SymbolsMenu $efrm.tags.entities.symbols ::prdoc::TextMenuInvoke

    if {$CONF(toolbarstyle) eq "icons"} {
      foreach {btn img} [list bold [mc gen.boldchar] italic [mc gen.italicchar] \
        code code pre pre sup sup sub sub ul ul ol ol li li lili lili reg X \
        keylbl key_6 fkeylbl key_6_gold gkeylbl key_6_blue f key_f g key_g] {
        $efrm.tags.$btn configure -image $ICONS($img) -compound image
      }
    }

    set cc 0
    foreach tt {bold italic code pre sep1 sup sub sep2 ul ol li lili sep3 reg \
      keylbl fkeylbl gkeylbl f g sep4 entities} {
      grid $efrm.tags.$tt -row 0 -column $cc -sticky ns
      incr cc
    }

    grid $efrm.tags -row 3 -column 0 -sticky nwe -columnspan 2

    ttk::button $efrm.mode -text [mc pdocu.preview] \
      -command "::prdoc::SetMode render"
    grid $efrm.mode -row 3 -column 1 -sticky ne

    ttk::frame $efrm.filler -height 5
    grid $efrm.filler -row 4 -column 1 -sticky we

    grid $efrm -row 3 -column 0 -padx 10 -sticky nwse
    grid columnconfigure $efrm 0 -weight 1
    grid rowconfigure $efrm 2 -weight 1

# Frame for rendering. A separate widget makes it easier to preserve the
# editing widget status (history, cursor, modified, etc.)
    set rfrm $fpd.render
    ttk::frame $rfrm

    text $rfrm.txt -width $dwid -height $dhei -font TkTextFont -wrap word \
      -undo false -yscrollcommand [list $rfrm.ysb set] -padx 2
    ttk::scrollbar $rfrm.ysb -orient vertical \
      -command [list $rfrm.txt yview]

    grid $rfrm.txt -row 0 -column 0 -sticky nwse -columnspan 2
    grid $rfrm.ysb -row 0 -column 2 -sticky ns

    ttk::button $rfrm.mode -text [mc gen.edit] -command "::prdoc::SetMode edit"
    grid $rfrm.mode -row 1 -column 1 -sticky ne

    ttk::frame $rfrm.filler -height 5
    grid $rfrm.filler -row 2 -column 1 -sticky we

    grid $rfrm -row 3 -column 0 -padx 10 -sticky nwse
    grid columnconfigure $rfrm 0 -weight 1
    grid rowconfigure $rfrm 0 -weight 1
    lower $rfrm

    grid $fpd -row 0 -column 0 -sticky nsew -padx 3
    grid columnconfigure $fpd 0 -weight 1
    grid rowconfigure $fpd 3 -weight 1

    if {![info exists DESC_T(D)] || $DESC_T(D) eq ""} {
      set authorship [string trim [string map \
        {"<" "&lt;" ">" "&gt;" "\u00a9" "&copy;" "&" "&amp;" "\"" "&quot;"} \
        $::HP15(authorship)]]
      set DESC_T(D) [regsub {(https?://|www\.)[\w\.\-~/]+} $authorship \
        {<a href="\0">\0</a>}]
    }

# Fill existing program description and set edit or preview mode
    if {[info exists DESC_T(D)]} {
      $efrm.txt replace 0.0 end $DESC_T(D)
      $efrm.txt edit reset
      $efrm.txt mark set insert 1.0
      if {$CONF(autopreview) && \
        [regexp {<\/[[:alpha:]][[:alnum:]]*>|<br>|<p>} $DESC_T(D)]} {
        {*}[$efrm.mode cget -command]
      } else {
        {*}[$rfrm.mode cget -command]
      }

    }
    set DocuChanged 0

# Button frame
    set bfrm .pdocu.btn
    ttk::frame $bfrm -relief flat -borderwidth 8
    ttk::label $bfrm.resshow -image $ICONS(collapse) -text [mc gen.resources] \
      -compound left
    ShowMarks 0 $bfrm.resshow

    ttk::button $bfrm.reload -text [mc pdocu.reload] -command "::prdoc::Reload"
    ttk::button $bfrm.ok -text [mc gen.ok] -command "::prdoc::Act yes" \
      -default active
    ttk::button $bfrm.cancel -text [mc gen.cancel] -command "::prdoc::Act no"

    grid $bfrm.resshow -row 0 -column 0
    grid $bfrm.reload -row 0 -column 2 -padx 20 -sticky e
    grid $bfrm.ok -row 0 -column 3 -padx 5 -sticky e
    grid $bfrm.cancel -row 0 -column 4 -padx 5 -sticky e
    grid $bfrm -row 2 -column 0 -sticky nsew
    grid columnconfigure $bfrm 1 -weight 1

    grid columnconfigure .pdocu 0 -weight 1
    grid rowconfigure .pdocu 0 -weight 1

    if {$::HP15(prgmname) ne ""} {
      wm title .pdocu "$::APPDATA(appname) [mc gen.program]: $::HP15(prgmname)"
    } else {
      wm title .pdocu "$::APPDATA(appname) [mc gen.program]: [mc pdocu.notsaved]"
    }

    wm minsize .pdocu [expr int([winfo width .pdocu]*0.67)] \
      [expr int([winfo height .pdocu]*0.85)]

# Bindings and tracking changes on description
    set wid $efrm.txt
    $wid edit modified 0
    update
    bind $bfrm.resshow <ButtonPress-1> "::prdoc::ShowMarks 1 %W"
    bind $wid <<Modified>> "::prdoc::Modified %W"
    bind $wid <$MODKEY(ctrl)-v> "::prdoc::ResetModified %W"
    bind $wid <$MODKEY(ctrl)-z> "::prdoc::ResetModified %W"
    bind $wid <$MODKEY(ctrl)-a> {%W tag add sel 1.0 end; break;}
    foreach tt [array names ADDTAG_BINDS] {
      lassign $ADDTAG_BINDS($tt) mk1 mk2 cc
      bind $wid <$MODKEY($mk1)-$MODKEY($mk2)-$cc> "::prdoc::AddTag $wid $tt"
    }
    foreach tt [array names ADDCHAR_BINDS] {
      lassign $ADDCHAR_BINDS($tt) mk1 kk cc
      bind $wid <$MODKEY($mk1)-$kk> "::prdoc::InsertText $wid $cc"
    }
    bind $wid <F5> "::prdoc::HighlightTags $efrm.txt"
    bind $wid <<B3>> "::prdoc::TagsMenu $efrm.txt"
    event add <<Symbols>> <$MODKEY(ctrl)-Button-3>
    bind $wid <<Symbols>> "::prdoc::EntryMenuPost $srf.symbols %W %X %Y"
    bind $wid <F3> ::prdoc::Search

    bind .pdocu <Return> "::prdoc::Return %W"
    bind .pdocu <Escape> "$bfrm.cancel invoke"

    if {[trace info variable ::prdoc::DESC_T] eq ""} {
      trace add variable ::prdoc::DESC_T write "::prdoc::Changed $wid"
    }

    wm protocol .pdocu WM_DELETE_WINDOW "::prdoc::Act no"

# Recover previous window position if available
    if {$geom ne ""} {
      regexp $geomRE $geom all w0xh0 w0 h0 xoff x0 yoff y0
      regexp $geomRE [winfo geometry .pdocu] all w1xh1 w1 h1 xoff x1 yoff y1

      if {$x0+$w1 > [winfo vrootwidth .]} {
        set x0 [expr [winfo vrootwidth .]-$w1-10]
      }
      if {$x0 < [winfo vrootx .]} { set x0 [expr [winfo vrootx .]+10] }

      if {$y0+$h1 > [winfo vrootheight .]} {
        set y0 [expr [winfo vrootheight .]-$h1-10]
      }
      if {$y0 < [winfo vrooty .]} { set y0 [expr [winfo vrooty .]+10] }

      wm geometry .pdocu [format "+%d+%d" $x0 $y0]
      update
    }

    wm attributes .pdocu -alpha 1.0
    raise .pdocu
    focus $efrm.txt

  }

}

# ------------------------------------------------------------------------------
proc ::prdoc::ReDraw {} {

  if {[winfo exists .pdocu]} {
    set geom "[winfo geometry .pdocu]"
    destroy .pdocu
    Draw $geom
  }

}

# ------------------------------------------------------------------------------
proc ::prdoc::Reload {} {

  variable DocuChanged

  if {[winfo exists .pdocu]} {
    if {$DocuChanged} {
      set answer [tk_messageBox -parent .pdocu -icon question -type yesno \
        -default yes -title [mc menu.prgmdocu] -message [mc pdocu.discard]]
      if {$answer eq "no"} { return }
    }

    set geom "+[winfo x .pdocu]+[winfo y .pdocu]"
    destroy .pdocu
    Edit $geom
  }

}

# ------------------------------------------------------------------------------
proc ::prdoc::Edit { {geom ""} } {

  variable prevpos
  variable DESC
  variable DESC_T

  array unset DESC_T
  array set DESC_T [array get DESC]

  if {$geom eq "" && $prevpos ne ""} {
    set geom $prevpos
  }

  Analyse $::PRGM
  Draw $geom

}