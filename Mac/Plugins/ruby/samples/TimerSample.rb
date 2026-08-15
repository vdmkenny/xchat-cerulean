# --------------------------------------------------------------------------
# TimerSample.rb -- sample ruby plugin script
# Copyright (C) Jamis Buck (jgb3@email.byu.edu)
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
# timer hooks.
#
# author: Jamis Buck (jgb3@email.byu.edu)
# --------------------------------------------------------------------------

include XChatRuby

class TimerSample < XChatRubyPlugin

  def initialize
    @timer_handle = nil

    hook_command( "RBStart", XCHAT_PRI_NORM, method( :start_timer ),
                  "Usage: /RBStart timeout, starts a timer, which pings every 'timeout' milliseconds" )
    hook_command( "RBStop", XCHAT_PRI_NORM, method( :end_timer ),
                  "Usage: /RBStop, stop the active timer" )
    puts_fmt "![c(blue)]TimerSample![c] loaded"
  end

  def start_timer( words, words_eol, data )
    if @timer_handle != nil
      puts "The timer is already running.  Use /rbstop to stop it."
    elsif !words[1]
      puts "You must specify the interval (in milliseconds) for the timer."
    else
      @timer_handle = hook_timer( words[1].to_i, method( :call_timer ) )
      puts "The timer has been started."
    end

    return XCHAT_EAT_ALL
  end

  def end_timer( words, words_eol, data )
    if @timer_handle == nil
      puts "The timer is not running.  Use /rbstart to start it."
    else
      unhook( @timer_handle )
      @timer_handle = nil
      puts "The timer has been stopped."
    end

    return XCHAT_EAT_ALL
  end

  def call_timer( data )
    puts_fmt "![bc(white)]PING ![c(ltgrey)]Ping![c] ![c(grey)]ping![cb]"
    return XCHAT_EAT_ALL
  end
end
