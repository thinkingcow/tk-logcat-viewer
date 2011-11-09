#!/bin/sh 
# The next line is a wish comment \
exec wish $0 -- ${1+"$@"} 
# Copyright 2011 Google Inc.
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# logcat.tcl By Stephen Uhler (Version 0.2)
# Graphical android/adb logcat viewer

# Text tag summary:
#  line date time level app pid msg
#     output columns
#  nl
#     newline
#  d_X, X=V,D,I,E,W
#     entire line with debug level
#  a_XXX, X=[app name]
#     entire line with the app name
#  m_$name:  Match for tag "name"
#  l_$name:  Entire line for tag "name"
#  c_$name:  Entire category for tag "name"

# Filters:
#  name: regexp or text of pattern
#  value: option setting category

# Global variables
# Counter	Line number for next logcat entry
# Device	The adb device ID of the current logcat window
# Fd		The file handle to read logcat data from adb
# Fields	The list of data fields to display in the logcat window
# Filters	Array that maps text snippets to their highlighting properties
#               in the form of 'tag value' 'tag property' and 'display column'
# G*		booleans, * represents all application tags. Determines whether
#		the tag sould be diplayed or not
# Gmode		boolean, determines 'search' or 'filter' mode
# Log		boolean, enable diagnostic output to stderr
# MsPerDay	Constant
# Searching	boolean, is search (or filter) mode enabled
# Shift		boolean, is the shift key down (for appending to quick filters
# Shortcuts	array, map a shortcut key (for bind) to its text description
# Stick		boolean, Does the scrollbar "stick" to the bottom when new output arrives
# TabAlign	List of tab alignment settings for the display (constant)
# Tabs		List of tab distances (in delta character widths)
# TabScale	Fudge factor for manipulating tab distances (ugh)
# Tags		array, maps app tag name to boolean (displayed/not-displayed)

set Version 0.2

# You may need to set this for windoz
# set env(PATH) "C:/Program Files/Android/android-sdk/platform-tools"


# destroy everything so we can re-source for debugging
catch {font delete base_font}
catch {eval destroy [winfo children .]}
catch {eval destroy [winfo children .]}
catch {
  fconfigure $Fd -block 0
  close $Fd
}

# globals associated with field checkboxes
eval unset -nocomplain [info globals G*] Filters Tabs Tags

# Set the field widths
set Tabs "5 5 6 1 15 5"
set TabAlign "left right left left right left"
# debugging
set TabFields "line\tdate\ttime\tL\ttag\tpid\tmessage\n"
set Fields "date time level app pid msg"
set Searching false

# Use same default debug level font colors as eclipse - for familiarity

array set LevelColors {
  E #C00
  W #E90
  D #00C
  I #0C0
}
  
font create base_font -family "nimbus mono l" -size 10

tk appname logcat
menu .menubar
. configure -menu .menubar
menu .menubar.file
menu .menubar.devices -postcommand select_device
menu .menubar.edit
menu .menubar.view
menu .menubar.tags -title "hide tags"
menu .menubar.help
.menubar add cascade -menu .menubar.file -label file
.menubar.file add command -label "Save Settings" -command save_settings \
    -accelerator ^s
.menubar.file add command -label "Exit" -command exit

.menubar add cascade -menu .menubar.devices -label devices
# XXX fill in devices menu here
.menubar add cascade -menu .menubar.edit -label edit
.menubar.edit add command -label "configure tags" -command "list_tags .tags"
.menubar.edit add command -label "clear all lines" -command clear_all \
    -accelerator ^x
.menubar.edit add command -label "reset adb log" -command clear_adb
.menubar.edit add command -label "relaunch adb" -command adb_init
.menubar.edit add command -label "stop adb" -command {adb_stop $Fd}
.menubar.edit add command -label "start adb" -command {adb_start $Fd}

.menubar add cascade -menu .menubar.view -label view
.menubar.view add command -label "bigger" -command "font_size 2" \
    -accelerator ^+
.menubar.view add command -label "smaller" -command "font_size -2" \
    -accelerator ^-

.menubar.edit add cascade -menu .menubar.edit.trim -label "trim lines"
menu .menubar.edit.trim
foreach i {100 1000 5000 10000} {
  .menubar.edit.trim add radiobutton -label "last $i lines" \
     -variable Gtrim -value $i -command "trim_lines $i"
}

.menubar add cascade -menu .menubar.tags -label tags

.menubar add cascade -menu .menubar.help -label help
.menubar.help add command -label "Help" -command show_help
.menubar.help add command -label "About" -command show_about
.menubar.help add command -label "shortcuts" -command show_shortcuts

set Log [info exists env(DEBUG)]
proc log {msg} {
  global Log
  if {1} {
    puts stderr $msg
  }
}

# Bind a shortcut key to a command

proc bind_all {key cmd desc} {
  global Shortcuts
  bind all <$key> "$cmd;break"
  bind .t <$key> "$cmd;break"
  set Shortcuts($key) $desc
}

# Manage the vertical scroll bar

proc sv_set {a b} {
   global Stick
   if {$b == "1"  && !$Stick} {set Stick 1}
  .sv set $a $b
}

# Not used (yet)
proc elide_continue {on} {
  if {$on} {
    .t tag configure dots -elide {}
    .t tag configure continue -elide true
  } else {
    .t tag configure dots -elide true
    .t tag configure continue -elide {}
  }
}

# Build the main GUI

frame .top
scrollbar .sv -command ".t yview"
scrollbar .sh -command ".t xview" -orient horizontal
text .t -yscrollcommand "sv_set" -xscrollcommand ".sh set" \
    -wrap none  -font base_font -background #E5E5E5
.t tag configure elapsed -elide true
.t tag configure dots -elide true

bind .t <Key> {do_key %K;break}
bind_all Control-equal "font_size 2" "Increase font size"
bind_all Control-minus "font_size -2" "Decrease font size"
bind_all Control-w ".top.wrap invoke" "Toggle wrap mode"
bind_all Control-x {clear_all [.t index {insert linestart}]} "Clear lines (from cursor)"
bind_all Control-s save_settings "Save settings for this device"

foreach {level color} [array get LevelColors] {
  .t tag configure d_$level -foreground $color
}

frame .bottom
grid .top -
grid .sv .t
grid ^   .sh
grid .bottom -
grid rowconfigure . 1 -weight 1 -minsize 150
grid columnconfigure . 1 -weight 1 -minsize 150
grid configure .top -stick w
grid configure .sh -stick ew
grid configure .sv -stick ns
grid configure .t -stick nsew
grid configure .bottom -stick ew

checkbutton .top.wrap -text wrap -command do_wrap
checkbutton .top.delta -text delta -variable Gxx -command {do_delta .top.delta $Gxx} -width 7
set Stick 1 ;# does output autoscroll
checkbutton .top.scroll -text "auto\nscroll" -variable Stick
# button .top.bigger -text + -command "font_size 2"
# button .top.smaller -text - -command "font_size -2"

# Set the mouse-click action

proc set_configure {win id what} {
  bind $win <1> "+cfg_on $win $id $what"
  bind $win <ButtonRelease-1> "set Cfg$id 0"
}

labelframe .top.levels -text "hide debug level" -labelanchor n
foreach i {V D I W E} col {0 1 2 3 4} {
  set b [checkbutton .top.levels.r$i -text $i -command "do_hide $i d_" -variable G$i]
  catch {$b configure -foreground $LevelColors($i)}
  set_configure $b $i foreground
  grid $b -column $col -row 0
}

labelframe .top.fields -text "hide field" -labelanchor n
set col 0
foreach i $Fields {
  set b [checkbutton .top.fields.$i -text $i -command "do_hide $i" -variable G$i]
  grid $b -column $col -row 0
  incr col
}
destroy .top.fields.msg

labelframe .top.filters -text "Quick Filters" -labelanchor n

set col 0

# I don't know how to activate the UI for setting colors.  This
# is a lame attempt

proc cfg_on {win id what} {
  upvar #0 Cfg$id data
  set data true
  after 2000 "cfg_win $win $id $what"
}

proc cfg_win {win id what} {
  upvar #0 Cfg$id data
  puts "CONFIG $win $id ($data)"
  if {$data} {
    set data 0
    change_color $id $win $what
  }
}

# allow the user to select the background colors for the widgets
# -id: the base of the tag name (e.g. d_$id)
# -win:  The window that has that color
# -what:  The property to set foreground/background
proc change_color {id win {what foreground}} {
  set color [tk_chooseColor -initialcolor [$win cget -$what] \
	-title "Set $what for $id"]
  if {$color != ""} {
    $win configure -$what $color
    .t tag configure d_$id -$what $color
    # make global so it gets persisted
    upvar #0 G$win data
    set data $color
  }
}

proc create_filter {color col} {
  set b [button .top.filters.c$color -text " " -background $color -padx 1 -pady 1]
  $b configure -command "do_color $b foreground $color"
  grid $b -column $col -row 0
  bind $b <Shift-1> "set_shift"
  set_configure $b $color background
}

# mac doesn't support background colors on buttons
if {$tcl_platform(os) == "Darwin"} {
  proc create_filter {color col} {
    set b [label .top.filters.c$color -text " " -background $color -border 2 \
      -relief raised]
    bind $b <Enter>
    bind $b <Leave>
    bind $b <1> "$b configure -relief sunken"
    bind $b <ButtonRelease-1> \
      "$b configure -relief raised; do_color $b foreground $color"
    grid $b -column $col -row 0
    bind $b <Shift-1> "set_shift"
    set_configure $b $color background
  }
}

foreach color {red blue magenta orange} col {0 1 2 3} {
  create_filter $color $col
}

button .top.filters.hide -text hide -command \
	"do_color .top.filters.hide elide true" -padx 1 -pady 1
bind .top.filters.hide <Shift-1> "set Shift 1"

grid .top.filters.hide -row 0 -column 4
button .top.filters.reset -text reset -command del_quick -padx 1 -pady 1
grid .top.filters.reset -row 0 -column 5
button .top.mark -text "insert\nmark" -command mark_here
button .top.clear -text "clear\nall" -command clear_all
grid .top.wrap .top.delta .top.scroll .top.levels .top.fields .top.filters .top.mark .top.clear

set search [entry .bottom.search -textvariable Gsearch]
set rs [button .bottom.reset -text cancel -command cancel_search]
set mode [checkbutton .bottom.mode -text search -variable Gmode -command {do_mode .bottom.mode $Gmode}]
grid $mode $search $rs
grid configure $search -stick ew
grid columnconfigure .bottom 1 -weight 1
bind .bottom.search <Return> {do_search $Gsearch}

# Keep track of the shift key for appending to quick filters
set Shift 0
proc set_shift {} {
  global Shift
  set Shift 1
}

# Clear all lines
proc clear_all {{end end}} {
  global Counter
  if {$end == "end"} {
    set Counter 1
  }
  log "Clear 1.0 $end"
  .t delete 1.0 $end
}

# Clear adb log

proc clear_adb {} {
  global Device
  set data [exec adb -s $Device logcat -c]
}

# Toggle time view: elapsed/delta
proc do_delta {win on} {
   set text(0) "elapsed\ntime"
   set text(1) "delta\ntime"
   set off [expr !$on]
   set_elide delta $off
   set_elide elapsed $on
   $win configure -text $text($on)
}

# the "elide" property should be either "true" or not set
# This helps with that

proc set_elide {tag what} {
  if {$what} {
    .t tag configure $tag -elide true
    log "hiding $tag"
  } else {
    .t tag configure $tag -elide {}
  }
}

# Toggle search/filter modes
proc do_mode {win on} {
  array set values "0 search 1 filter"
  $win configure -text $values($on)
  catch {filter_search $on}
}

proc show_help {} {
   tk_messageBox -title Help -message \
     "Select some text, then click (or shift-click) on a quick filter"
}

proc show_about {} {
   global Version
   tk_messageBox -title About -message \
     "Prototype LogCat viewer Version $Version by suhler"
}

proc show_shortcuts {} {
   global Shortcuts
   foreach i [lsort [array names Shortcuts]] {
     append message "$i\t$Shortcuts($i)\n"
   }
   tk_messageBox -title shortcuts -message $message
}

# Change the global font size
proc font_size {incr} {
   set size [font configure base_font -size]
   font configure base_font -size [expr {$size + $incr}]
   reset_tabs
}

# Recompute the tab stops based on the font size and dislayed fields
# This is kind of a pain (and still broken.  Oh well)
set TabScale .95
proc reset_tabs {} {
  global Tabs Fields TabScale TabAlign
  set size [font configure base_font -size]
  set start 0
  set skip 0
  foreach i $Tabs item $Fields align $TabAlign {
    upvar #0 G$item value
    # log " skip=$skip item=$item"
    if {!$skip} {
      incr start $i
      lappend next [expr {$start * $size * $TabScale}]p
      # lappend next $align
    }
    set skip $value
  }
  log "tabs: $next"
  .t configure -tabs $next
  return $next
}
   
# delete all the "quick" tags

proc del_quick {} {
  global Filters
  set remove nothing
  catch {unset Filters}
  catch {unset Tags}
  foreach tag [.t tag names] {
    if {[string first l_ $tag] == 0} {lappend remove $tag}
    if {[string first m_ $tag] == 0} {lappend remove $tag}
    if {[string first c_ $tag] == 0} {lappend remove $tag}
  }
  log "Removing: $remove"
  eval .t tag delete $remove
}

# toggle wrap
proc do_wrap {} {
  global wrap
  array set value "0 none 1 word"
  .t configure -wrap $value($wrap)
}

proc show_help {} {
   set message "
     * Make sure 'adb' is on your path.\n
     * Select text to hightlight, then click (or shift click) on a quick filter\n
     * Click and hold on check-boxes to edit colors\n
     * Clicking on an application tag brings the tag in menu->edit->configure tags window into view\n
     * The Search filter is an arbitrary regular expression
   "
   tk_messageBox -title Help -message $message
}
proc show_about {} {
   global Version
   tk_messageBox -title About -message \
     "Prototype LogCat viewer Version $Version by suhler"
}

proc show_shortcuts {} { 
   global Shortcuts
   foreach i [lsort [array names Shortcuts]] {
     append message "$i\t$Shortcuts($i)\n"
   }
   tk_messageBox -title shortcuts -message $message
}    

# Hide or un-hide a tag based on checkbox's global value
proc do_hide {what {prefix "" }} {
  upvar #0 G$what value
  set_elide $prefix$what $value
  reset_tabs ;# more work than needed
}

# Color items based on the current selection and region
proc do_color {win option value} {
  global Shift
  log "$option/$value ($Shift)"
  # reset filter.  Remove to add
  if {!$Shift} {
    .t tag delete c_$value$option m_$value$option l_$value$option
  }

  set Shift 0
  foreach {i1 i2} [.t tag ranges sel] break
  if {![info exists i1]} {
    log "No selection range ($win $option $value)"
    return 
  }
  set text [string trim [.t get $i1 $i2]]
  set cat [get_category $i1]
  apply_config $text $option $value $cat
  foreach i "c l m" {catch {.t tag raise ${i}_$value$option}}
}

# Apply a tag configuration
# - text:  The text that names this configuration 
# - option The tag option to set
# - value  The option's value
# - cat    The category (e.g which column) to set the configuration on
proc apply_config {text option value {cat all} {start 1.0}} {
  global Filters
  if {$start == "1.0"} {
     set Filters($text) [list $value $option $cat]
  }
  add_tag $text $value$option $cat $start
  set prefix c
  if {$option == "elide"} {set prefix l}

  # log ".t tag configure c_$value$option -$option $value"
  .t tag configure ${prefix}_$value$option -$option $value
  if {$cat == "msg"} {
    .t tag configure m_$value$option -border 2 -relief ridge
  }
}

# testing

proc G {} {
  foreach i [lsort [info globals G*]] {
    upvar #0 $i value
    log "$i=$value"
  }
}

# save the global variable states (this needs work)

proc save_settings {} {
  global env Device
  file mkdir $env(HOME)/.logcow
  set file $env(HOME)/.logcow/$Device
  set fd [open $file w]
  puts $fd "# [clock format [clock seconds]]"
  foreach i [lsort [info globals G*]] {
    upvar #0 $i value
    puts $fd "set [list $i] [list $value]"
  }
  close $fd
}

proc load_settings {} {
  global env Device
  catch {uplevel #0 {source $env(HOME)/.logcow/$Device}}
  log "init $Device"
  restore_tags
}

proc restore_tags {} {
  foreach i [lsort [info globals Gtag*]] {
    upvar #0 $i value
    regexp Gtag(.*) $i all tag
    set_elide t_$tag $value
  }
}

proc get_devices {} {
  set devices ""
  foreach line [split [exec adb devices] \n] {
    if {[llength $line] == 2 && [lindex $line 1] == "device"} {
       lappend devices [lindex $line 0]
    }
  }
  return $devices
}

# Read the next line of adb output
set Counter 1		;# line counter
set Continue ""		; # track continuation lines
proc next_line {fd} {
  global Counter Fields Searching Stick Continue ContinuationLines
  if {[eof $fd]} {
    .t insert end "---  Adb Terminated ---\n" 
    incr Counter
    close $fd
    return
  }
  set line [gets $fd]
  # log $line
  if {$Counter%25 == 0} {update idletasks}
  set parsed [parse_line $line]
  if {$parsed == "error"} {
    # log "Skipping: $line"
    return
  }
  incr Counter
  # "date time level app pid msg"
  foreach $Fields $parsed break

  # adjust fields a bit
  if {[string trim $app] == ""} {
     set app "none"
  }

  track_tags $app

  # toss lines for tags that are hidden?
  upvar #0 Gtag$app skip
  if {$skip} {
    log "Skipping $app?"
    return
  }
  # if new tag and tags menu is posted - we should append the item onto the end

  set delta [compute_delta $time]
  set same $level$app$pid	;# for continuation lines
  set here [.t index "end - 1 lines"]
 
  if {$delta == "0ms" && $same == $Continue} {
    if {$ContinuationLines == 0} {
      .t insert "end - 2 chars" "..." dots
    }
    incr ContinuationLines
    .t insert end \
        $Counter\t lines \t date \t "time elapsed" \t "time delta" \
        \t level \t app \t pid $msg msg "\n" "nl nlc"
    .t tag add continue $here "end +1 chars"
  } else {
    set ContinuationLines 0
    set app2 [string range $app 0 15]
    .t insert end \
        $Counter\t lines $date\t date $time\t "time elapsed" $delta\t "time delta" \
        $level\t level $app2\t app $pid\t pid $msg msg "\n" nl
  }
  foreach i {level app} j {d t} { # was level app pid
    .t tag add ${j}_[set $i] $here "end +1 chars"
  }
  set Continue $same
  apply_filters $here
  
  # Current search
  global Gsearch
  if {$Searching} {
    add_tag $Gsearch search none $here  "-regexp"
    global Gmode
    if {$Gmode} {
      .t tag add hidden $here end
    }
  }
  if {$Stick} {
    .t see end
  }
}

# mark the current end
proc mark_here {} {
  .t insert end "\t\t\t\t\t\tMARK" mark "\n" nl
  .t tag configure mark -background red
}

# compute deltas (in ms)
# if delta > 9999ms, convert to seconds and bold face

set Previous ""
proc compute_delta {time} {
  global Previous
  set now [get_seconds $time]
  if {$Previous == "" } {
    set delta 1
  } else {
    set delta [get_delta $now $Previous]
  }
  set Previous $now
  if {$delta > 9999} {
    set delta [expr $delta/1000]S
  } else {
    set delta ${delta}ms
  }
  return $delta
}

# Trim to n lines
proc trim_lines {{n 2500}} {
  log "trimming to last $n lines"
  .t delete 1.0 "end -$n lines" 
}

# Keep track of our tags
set AddTag 0 ;# Have we tacked new tags onto the bottom of the list?
set Hide_tags 0 ;# are all tags being "hidden"
proc track_tags {app} {
  global Tags AddTag Hide_tags
  if {![info exists Tags($app)]} {
    set Tags($app) 1
    upvar #0 Gtag$app value
    set value $Hide_tags
  }
  return
}

# apply the filters to incoming lines

proc apply_filters {start} {
  global Filters
  foreach {name value} [array get Filters] {
    foreach {setting option cat} $value break
    apply_config $name $option $setting $cat $start
  }
}

# parse a logcat -v time output
# 05-09 hh:mm:ss.ms I/UIB ( 4264): Function.get:174...ling function: saved
proc parse_line {line} {
  # log $line
  if {[regexp {([0-9-]+)\s*([0-9:]+[.][0-9]+)\s*([A-Z])/([^(]*)[(]\s*([0-9]+)[)]:\s*(.*)} \
     $line all date time level app pid msg]} {
    return [list $date $time $level [string trim $app] $pid $msg]
  }
  return "error"
}

# turn logcat date into ms
# Watch out for octal numbers!

proc get_seconds {date} {
  regexp {0?([^:]+):0?([^:]+):0?([^.]+)[.]0?0?(.*)} $date all h m s ms
  set time [expr {((((($h * 60) + $m) * 60) + $s) * 1000) + $ms}]
  return $time
}

# turn 2 timestamps into a delta in seconds

set MsPerDay [expr {1000 * 60 * 60 * 24}]
proc get_delta {next prev} {
  global  MsPerDay
  set delta [expr {$next - $prev}]
  while {$delta < 0} {
    incr delta $MsPerDay
  }
  return $delta
}

# Do a search
proc do_search {text} {
  global Searching
  set Searching false
  log "search: ($text)"
  .t tag delete m_search l_search c_search
  .t tag configure m_search -background yellow
  if {[string trim $text] != ""} {
    add_tag $text search none 1.0 "-regexp"
    set Searching true
    global Gmode
    catch {filter_search $Gmode}
  }
}

proc cancel_search {} {
  set Searching false
  .t tag delete m_search l_search c_search hidden
}

# find all lines that match, and add a tag
# exp:		Regular expression to match
# name:		The name of the tag to add
# tag:		Restrict new tag to intersect this tag
# start:	start looking here
# return: 3 tags added:
# - m_$name:  exact match
# - l_$name:  entire line match
# - c_$name:  entire category (if tag is defined)

proc add_tag {exp name {tag none} {start 1.0} {reg "-exact"}} {
  set count 0
  while {1} {
    set i1 [.t search $reg -count end -elide -forwards -- $exp $start end]
    if {$count == 0} {
      set done $i1
    } elseif {"x$done" == "x$i1"} {
      break
    }
    if {$i1 == ""} break
    incr count
    .t tag add m_$name $i1 "$i1 + $end chars"
    set start "$i1 + $end chars"
    .t tag add l_$name "$i1 linestart" "$i1 lineend + 1 chars"
    if {$tag != "none"} {
       foreach {i1 i2} [.t tag nextrange $tag "$i1 linestart"] break
       if {[info exists i2]} {
        .t tag add c_$name $i1 $i2
       }
    }
  }
  # log "  add_tag: $exp/$name/$tag ($start) -> $count ranges"
  return $count
}

# Return the category for this index
proc get_category {index} {
    set category unknown
    regexp { (line|date|time|level|app|pid|msg) } " [.t tag names $index] " all category
    log "category: $index -> $category"
    return $category
}

# All keystrokes go here for dispatch
proc do_key {key} {
  log "<$key>"
  catch {do_key_$key}
}

# Find the next match
proc do_key_n {} {
  foreach {i1 i2} [.t tag nextrange m_search "insert + 1 chars"] break
  log $i1
  if {$i1 != ""} {
    log "$i1 $i2"
    .t tag delete underline
    .t tag add underline $i1 $i2
    .t tag configure underline -underline true
    .t mark set insert $i1
    .t see insert
  }
}

# manage tags (via the menu)

proc all_tags {show} {
  global Hide_tags
  set Hide_tags $show
  log "show $show"
  foreach var [info globals Gtag*] {
    upvar #0 $var item
    set item $show
  }
  # now reset the visibility

  foreach tag [.t tag names] {
    if {[regexp ^t_ $tag]} {
      set_elide $tag $show
    }
  }
}

# Select the tags.  Too many for a menu, so this needs a redo

.menubar.tags configure -postcommand "tag_menu .menubar.tags"
proc tag_menu {menu} {
  global Tags AddTag
  set AddTag 0
  $menu delete 0 last
  $menu add command -label "show all" -command "all_tags 0"
  $menu add command -label "hide all" -command "all_tags 1"
  $menu add separator
  # sigh
  set count 0
  catch "destroy [info commands .menubar.tagsa*]"

  foreach item [lsort -dictionary [array names Tags]] {
    $menu add checkbutton -label $item -variable Gtag$item -command [list change_menu $item]
    incr count
    set add a
    if {$count > 30} {
      menu $menu$add
      $menu add cascade -menu $menu$add -label "more tags"
      set menu $menu$add
      set count 0
    }
  }
}

proc change_menu {tag} {
  upvar #0 Gtag$tag on
  set_elide t_$tag $on
  log "menu $tag $on"
}

# Initialize adb

proc adb_init {} {
  global Fd Counter TabFields argv Device
  wm title . "Logcat Disabled"
  .t insert end "--- Adb reset ---\n"
  .t insert end $TabFields
  incr Counter 2
  log "Closing ..."
  catch {
    fconfigure $Fd -block 0
    close $Fd
  }
  log "opening $Device"
  set Fd [open "|adb -s $Device logcat -v time $argv"]
  wm title . "Logcat for $Device"
  adb_start $Fd
  load_settings
}

proc adb_start {fd} {
  log "Starting $fd"
  fileevent $fd r "next_line $fd"
}

proc adb_stop {fd} {
  log "Stopping $fd"
  fileevent $fd r  {}
}

proc filter_search {on} {
  .t tag delete hidden
  if {$on} {
    .t tag configure hidden -elide true
    .t tag add hidden 1.0 end
    .t tag configure l_search -elide false
    .t tag lower m_search
    .t tag lower l_search
    .t tag lower hidden
  } else {
    .t tag configure l_search -elide {}
    .t tag raise m_search
  }
}
    
# experiment with more flexible tag settings

proc list_tags {win} {
  if {[winfo exists $win]} {
    raise $win
    update_tags $win
    return
  }
  toplevel $win
  wm title $win "Configure Tag Settings"
  listbox $win.list -listvariable Tag_list -yscrollcommand "$win.s set"
  scrollbar $win.s -command "$win.list yview"
  labelframe $win.f -text "Tag Settings" -labelanchor n

  frame $win.bottom
  button $win.bottom.refresh -text "refresh tag list" -command "update_tags $win"
  button $win.bottom.hideall -text "hide all" -command "all_tags 1"
  button $win.bottom.showall -text "show all" -command "all_tags 0"
  grid $win.bottom.refresh $win.bottom.showall $win.bottom.hideall

  grid $win.s $win.list $win.f
  grid $win.bottom - -
  grid columnconfigure $win 1 -weight 1
  grid configure $win.s -stick ns
  grid configure $win.list -stick nswe
  grid configure $win.f -stick n
  grid rowconfigure $win 0 -weight 1
  bind $win.list <<ListboxSelect>> "list_select $win"

  # The configuration panel

  label $win.label -textvariable Current_tag -width 20
  checkbutton $win.show -text hide -command {change_menu $Current_tag}
  frame $win.bg
  set col 0
  foreach i {fff efe fef eff ffe} {
    button $win.bg.$i -text " " -background #$i -command "tag_bg $win #$i" -padx 2
    grid $win.bg.$i -column $col -row 0 
    incr col
  }
  button $win.bg.reset -text reset -command "tag_bg $win {}" -padx 2

  grid $win.bg.reset -column $col -row 0 

  grid $win.label -in $win.f
  grid $win.show -in $win.f
  grid $win.bg -in $win.f
  update_tags $win
}

proc tag_bg {top color} {
  global Current_tag Tag_list
  .t tag configure t_$Current_tag -background $color
   $top.list itemconfigure [lsearch -exact $Tag_list $Current_tag] \
       -background $color
}

proc list_select {toplevel} {
  global Tag_list Current_tag
  set Current_tag [lindex $Tag_list [$toplevel.list curselection]]
  $toplevel.show configure -variable Gtag$Current_tag
  puts $Current_tag
}

proc update_tags {win} {
  global Tag_list Tags
  set Tag_list [lsort -dictionary [array names Tags]]
  set i 0
  foreach tag $Tag_list {
    .t tag bind t_$tag <1> "see_tag $win $tag $i"
    incr i
  }
}

proc see_tag {win tag index} {
  log "See $win-$tag-$index"
  catch {
    $win.list see $index
    $win.list selection clear 0 end
    $win.list selection set $index
    event generate $win.list  <<ListboxSelect>>
  }
}

proc select_device {} {
  set devices [get_devices]
  .menubar.devices delete 0 end
  foreach device $devices {
    .menubar.devices add radiobutton -label $device -variable Device -value $device -command adb_init
  }
  return [lindex $devices 0]
}


# end tag-setting experiment

reset_tabs
.t tag configure msg -lmargin2 30

# override setting in lieu of a proper prefence settings

if {[catch {
  source $env(HOME)/.logcatrc
  }]} {
   tk_messageBox -title "Error" -message \
     "Startup file error: ${errorInfo}"
}

if {[get_devices] != ""} {
  set Device [select_device]
  adb_init
} else {
  wm title . "No Android Devices connected"
}
puts "ready"
