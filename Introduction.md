# Introduction #

This is a short tcl/tk program that displays ongoing android
`logcat` information using a TK text widget, allowing the user
to dynamically control the display and visibility attributes of various
portions of the `logcat` output by manipulating the text "tags".

I find it usable as-is, although more features come to mind.  I plan to add them as need and time permit. Suggestions and contributions are welcome.

I use is as a replacement for the logcat view in eclipes (sometimes), or when I don't feel like firing up eclipse to inspect the logs.

# Some Features #

  * Displays either delta or elapsed event times
  * Multiple filters can be active at once - each with its own highlight color
  * Multiple line log messages are coalesced
  * Long output lines are always visible, either by wrapping or scrolling
  * Easy font re-sizing for the visually challenged
  * Multiple instances can be used to inspect logs from several devices at once

# Screenshots #

## Main window ##

![http://tk-logcat-viewer.googlecode.com/git/documentation/screenshot1.png](http://tk-logcat-viewer.googlecode.com/git/documentation/screenshot1.png)

## Application tag selector window ##

![http://tk-logcat-viewer.googlecode.com/git/documentation/screenshot2.png](http://tk-logcat-viewer.googlecode.com/git/documentation/screenshot2.png)

# Configuration #

There isn't much in the way of configuration options (yet), but
you can customize the application by putting TCL commands in a file
called ".logcatrc" in your home directory.  Here is a simple example:
```
# set local logcat preferences

.t configure -background #EEEEEE  ;# lighten the background color
font configure base_font -weight bold -size 14  ;# set the base font
reset_tabs  ;# recompute the tab settings based on the new font size

```

# Download #

[logcat.tcl](http://tk-logcat-viewer.googlecode.com/git/src/logcat.tcl)