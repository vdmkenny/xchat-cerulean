# --------------------------------------------------------------------------
# JBanner.rb -- sample ruby plugin script
# Copyright (C) 2003 Jamis Buck (jgb3@email.byu.edu)
# --------------------------------------------------------------------------
# This file is part of the XChat-Ruby plugin.
# 
# The  XChat-Ruby  plugin  is  free software; you can redistribute it and/or
# modify  it  under the terms of the GNU General Public License as published
# by  the  Free  Software  Foundation;  either  version 2 of the License, or
# (at your option) any later version.
# 
# The  XChat-Ruby  plugin is distributed in the hope that it will be useful,
# but   WITHOUT   ANY   WARRANTY;  without  even  the  implied  warranty  of
# MERCHANTABILITY  or  FITNESS  FOR  A  PARTICULAR  PURPOSE.   See  the  GNU
# General Public License for more details.
# 
# You  should  have  received  a  copy  of  the  GNU  General Public License
# along  with  the  XChat-Ruby  plugin;  if  not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
# --------------------------------------------------------------------------
# This is a sample ruby plugin script for XChat2, demonstrating the use of
# timer and command hooks.  It also demonstrates the use of the
# "unload_plugin" method for saving data when a plugin is unloaded.
#
# This sample allows a user to define a "banner"---a timed message that
# is shouted to a set of channels that the user specifies.  The banner will
# only be shouted to channels that the user has currently joined.
#
# You may specify either a filename for the banner (in which case, the
# banner's text will be the contents of the file), or a command to
# execute (in which case, prefix the name of the command with a '!').
#
# You may also specify an interval (in seconds) for how often the banner
# should be shouted to the specified channels.
#
# For more information on how to use this plugin, load it and type
# "/banner help".
#
# author: Jamis Buck (jgb3@email.byu.edu)
# --------------------------------------------------------------------------

include XChatRuby

class BannerDefinition
  attr_reader :file
  attr_reader :name
  attr_reader :interval
  attr_reader :channels
  attr_reader :last_shout
  attr_reader :enabled

  def initialize( plugin, file, name, interval, channels, enable = true )
    @plugin = plugin
    @file = file
    @name = name
    @interval = interval
    @channels = channels.split( / / )
    @enabled = false

    @last_shout = Time.now
    @timer_hook = nil

    activate if enable
  end

  def content
    if @file[0].chr == '!'
      return `#{file[1..-1]}`
    elsif @content
      return @content
    else
      read_banner( @file )
      return @content
    end
  end

  def read_banner( file )
    @content = ""

    begin
      File.open( file, "r" ) do |f|
        @content = format( f.readlines.join.strip )
      end
    rescue Exception => detail
      @plugin.puts "Could not open file '#{file}' (#{detail.message})"
    end
  end

  def shout( channels = nil )
    channels = @channels if !channels

    open_channels = []
    chan_list = XChatRuby::XChatRubyList.new( "channels" )
    while chan_list.next do
      next if chan_list.int( "type" ) != 2 # only look for "channel" tabs/windows
      open_channels.push( chan_list.str( "channel" ) )
    end

    channels.each do |chan|
      # don't shout to any channels that are not currently active
      next if !open_channels.include? chan
      @plugin.command( "MSG #{chan} #{content}" )
    end
  end

  def shout_and_reset( channels = nil )
    shout( channels )
    reset_last_shout
  end

  def reset_last_shout
    @last_shout = Time.now
  end

  def time_to_next_shout
    elapsed = Time.now - @last_shout
    @interval - elapsed
  end

  def is_active?
    @enabled
  end

  def activate
    return if @enabled
    @timer_hook = @plugin.hook_timer( @interval*1000, method( :timer ) )
    @enabled = true
  end

  def deactivate
    return if !@enabled
    @plugin.unhook( @timer_hook )
    @timer_hook = nil
    @enabled = false
  end

  def change_interval( i )
    e = @enabled
    deactivate
    @interval = i
    activate if e
  end

  def timer( data )
    shout_and_reset
    return XChatRuby::XChatRubyPlugin::XCHAT_EAT_ALL
  end

  def serialize( stream )
    stream << @name << "\n"
    stream << @file << "\n"
    stream << @interval << "\n"
    stream << @channels.join( " " ) << "\n"
    stream << ( @enabled ? "enabled" : "disabled" ) << "\n"
  end

  def BannerDefinition.unserialize( plugin, stream )
    name = stream.gets.chomp
    file = stream.gets.chomp
    interval = stream.gets.chomp.to_i
    channels = stream.gets.chomp
    enabled = ( stream.gets.chomp.downcase == "enabled" )

    return BannerDefinition.new( plugin, file, name, interval, channels, enabled )
  end
end


class JBanner < XChatRubyPlugin

  def initialize
    @banner_name = format( "![c(blue)b]JBanner![cb]" )

    @banners = []

    hook_command( "Banner", XCHAT_PRI_NORM, method( :banner_command ),
                  "Usage: Banner <cmd>, see /banner help for more info" )

    load_active_banners

    puts "#{@banner_name} loaded (see /banner help for more info)"
  end

  def open_banner_file( mode )
    bannerfile = nil
    begin
      bannerfile = File.open( get_info( "xchatdir" ) + "/banners", mode )
    rescue Exception => detail
    end
    return bannerfile
  end

  def load_active_banners
    file = open_banner_file( "r" )
    return if !file
    while !file.eof? do
      @banners.push BannerDefinition.unserialize( self, file )
    end
    file.close
  end

  def banner_command( words, words_eol, data )
    if words.length < 2
      puts "Please specify a command with /banner"
    else
      case words[1].downcase
        when "help" then
          return banner_help( words, words_eol, data )
        when "about" then
          return banner_about( words, words_eol, data )
        when "add" then
          return banner_add( words, words_eol, data )
        when "remove" then
          return banner_remove( words, words_eol, data )
        when "shout" then
          return banner_shout( words, words_eol, data )
        when "enable" then
          return banner_enable( words, words_eol, data )
        when "disable" then
          return banner_disable( words, words_eol, data )
        when "list" then
          return banner_list( words, words_eol, data )
        when "addchan" then
          return banner_addchan( words, words_eol, data )
        when "rmchan" then
          return banner_rmchan( words, words_eol, data )
        when "show" then
          return banner_show( words, words_eol, data )
        when "adjust" then
          return banner_adjust( words, words_eol, data )
        else
          puts "Unknown command '#{words[1]}'"
      end
    end

    return XCHAT_EAT_ALL
  end

  def banner_help( words, words_eol, data )
    puts
    puts "/banner help ...................................... this message"
    puts "        about ..................................... about this plugin"
    puts "        list ...................................... lists all banners"
    puts "        add <name> <file> <interval> <channels> ... add a new banner"
    puts "        remove <name> ............................. removes the named banner"
    puts "        shout <name> [<channels>] ................. shout (display) the named banner"
    puts "        enable <name> ............................. enable the given banner"
    puts "        disable <name> ............................ disable the given banner"
    puts "        addchan <name> [<channels>] ............... adds banner to the channels"
    puts "        rmchan <name> [<channels>] ................ removes banner from the channels"
    puts "        show <name> ............................... display (but don't shout) banner"
    puts "        adjust <name> <interval> .................. change interval for banner"
    puts
    puts "The <file> parameter to add may either be a filename, or a command to execute"
    puts "(in which case, the output of the banner is the output from the command).  To"
    puts "specify a command, prefix the command name with a '!' character."
    puts
    return XCHAT_EAT_ALL
  end

  def banner_about( words, words_eol, data )
    puts_fmt "#{@banner_name} v. 1.0, by ![c(yellow)b]Jamis Buck![cb] <jgb3@email.byu.edu>"
    puts_fmt "![c(red)]>>![o] Banner management script for XChat2 with XChat-Ruby plugin"
    puts
    return XCHAT_EAT_ALL
  end

  def banner_add( words, words_eol, data )
    name = words[2]
    file = words[3]
    interval = ( words[4] || "0" ).to_i
    channels = ""

    5.upto(words.length-1) do |i|
      channels << words[i] << " "
    end

    if !name || !file || interval < 1 || channels.length < 1
      puts "You must specify a name, a file, an interval, and at least one channel to add a banner."
      return XCHAT_EAT_ALL
    end

    banner = BannerDefinition.new( self, file, name, interval, channels )

    file = open_banner_file( "a" )
    if file
      banner.serialize( file )
      file.close
    end

    @banners.push banner

    puts "Banner '#{name}' has been added"

    return XCHAT_EAT_ALL
  end

  def banner_remove( words, words_eol, data )
    b = get_banner( words )

    if b
      b.deactivate
      @banners.delete( b )

      write_all_banners

      puts "Banner '#{b.name}' has been removed."
    end

    return XCHAT_EAT_ALL
  end

  def banner_shout( words, words_eol, data )
    b = get_banner( words )

    if b
      channels = ( words_eol[3] || "" ).strip.split( / / )
      channels = nil if channels.length < 1

      b.shout( channels )
    end

    return XCHAT_EAT_ALL
  end

  def banner_enable( words, words_eol, data )
    b = get_banner( words )

    if b
      if b.is_active?
        puts "Banner '#{b.name}' is already enabled."
      else
        b.activate
        puts "Banner '#{b.name}' has been enabled."
      end
    end

    return XCHAT_EAT_ALL
  end

  def banner_disable( words, words_eol, data )
    b = get_banner( words )

    if b
      if !b.is_active?
        puts "Banner '#{b.name}' is already disabled."
      else
        b.deactivate
        puts "Banner '#{b.name}' has been disabled."
      end
    end

    return XCHAT_EAT_ALL
  end

  def banner_list( words, words_eol, data )
    if @banners.length < 1
      puts "There are no banners to list."
    else
      puts "Banners:"
      @banners.each do |banner|
        puts_fmt "  ![c(yellow)b]#{banner.name}![cb] every ![c(yellow)b]#{banner.interval}![cb] seconds"
        puts_fmt "     channels  : ![c(yellow)b]#{banner.channels.join(', ')}![cb]"
        puts_fmt "     source    : ![c(yellow)b]#{banner.file}![cb]"
        puts_fmt "     enabled   : ![c(yellow)b]#{banner.enabled.to_s}![cb]"
        puts_fmt "     last shout: ![c(yellow)b]#{banner.last_shout}![cb]"

        if banner.enabled
          left = banner.time_to_next_shout.to_i
          hours = left / 3600
          minutes = ( left % 3600 ) / 60
          seconds = left % 60
          puts_fmt "     next shout: ![c(yellow)b]%02dh %02dm %02ds![cb]" % [ hours, minutes, seconds ]
        end
      end
      puts
    end

    return XCHAT_EAT_ALL
  end

  def banner_addchan( words, words_eol, data )
    b = get_banner( words )

    if b
      channels = ( words_eol[3] || "" ).split( / / )

      if channels.length < 1
        puts "You must specify at least one channel to add the banner to."
      else
        channels.each do |chan|
          b.channels.push chan
        end
        puts "Banner #{b.name} has been added to: #{channels.join(', ')}"
      end

      write_all_banners
    end

    return XCHAT_EAT_ALL
  end

  def banner_rmchan( words, words_eol, data )
    b = get_banner( words )

    if b
      channels = ( words_eol[3] || "" ).split( / / )

      if channels.length < 1
        puts "You must specify at least one channel to remove the banner from."
      else
        channels.each do |chan|
          b.channels.delete chan
        end
        puts "Banner #{b.name} has been removed from: #{channels.join(', ')}"
      end

      write_all_banners
    end

    return XCHAT_EAT_ALL
  end

  def banner_show( words, words_eol, data )
    b = get_banner( words )

    if b
      puts_fmt "![c(red)]>>-------------![c]"
      puts_fmt "Content of ![c(yellow)b]#{b.name}![cb]:"
      print b.content
      puts_fmt "![c(red)]>>-------------![c]"
    end

    return XCHAT_EAT_ALL
  end

  def banner_adjust( words, words_eol, data )
    b = get_banner( words )

    if b
      if !words[3]
        puts "You must specify an integer interval value (in seconds) for the banner."
      else
        interval = words[3].to_i
        if interval < 1
          puts "You must specify an interval of at least 1 second."
        else
          b.change_interval interval
          puts "The interval for #{b.name} has been changed to #{interval} seconds."
        end
      end
    end

    return XCHAT_EAT_ALL
  end

  def write_all_banners
    file = open_banner_file( "w" )
    if !file
      puts "The banner file could not be opened for writing..."
      return
    end

    @banners.each { |banner| banner.serialize( file ) }
    file.close
  end

  def get_banner( words )
    banner = words[2]
    if !banner
      puts "You must specify the name of a banner."
      return nil
    end

    b = @banners.find { |i| i.name.downcase == banner.downcase }
    if !b
      puts "There is no banner by that name (#{banner})."
      return nil
    end

    return b
  end

  def unload_plugin
    write_all_banners
    super
  end

end
