# a script for building the plugin under windows.
# assumes that ruby is installed, can be found in the PATH, and that you are
# using MSVC++ to compile the plugin.

require 'rbconfig'

def exec_syscmd( cmd )
  system( cmd + " > /dev/null")
end


$archdir = Config::CONFIG['archdir']
$libs    = Config::CONFIG['LIBS']

# first, process the header file
puts "Building 'xchat-ruby-plugin.h'..."
exec_syscmd( "ruby ..\\scripts\\embedify.rb xchat-ruby-plugin.rb xchat-ruby-plugin.h" )

# now, compile the plugin
puts "Compiling xchat-ruby.c..."
exec_syscmd( "cl -O1 -MD -G5 -DWIN32 -c -I#{$archdir} xchat-ruby.c" )

# link the plugin
puts "Linking library..."
exec_syscmd( "link /LIBPATH:#{$archdir} /DLL /out:xchat-ruby.dll /SUBSYSTEM:WINDOWS xchat-ruby.obj libruby.lib #{$libs} /def:win32/xchat-ruby.def" )

# build the ruby environment file
puts "Building the ruby environment file..."
File.open( "rubyenv", "w" ) { |f| f.puts $LOAD_PATH.join( "\n" ) }

puts "Cleaning up..."
File.delete "xchat-ruby-plugin.h", "xchat-ruby.obj", "xchat-ruby.exp", "xchat-ruby.lib"

puts "Done!"
