# --------------------------------------------------------------------------
# BookSearch.rb -- search a book channel and request one result at a time
# --------------------------------------------------------------------------
# This file is part of XChat Cerulean and is distributed under the same
# terms as the rest of the XChat-Ruby plugin: the GNU General Public
# License, version 2 or later.
# --------------------------------------------------------------------------
#
# Book channels work by handing you a file. You ask a search bot for a
# subject, it sends back an archive listing what the bots on the channel
# have, and each line of that listing is itself the command that requests
# one item. Reading the archive by hand and pasting a line back is the slow
# part, so this reads it for you and keeps the list to hand.
#
#   /bsearch <terms>   ask the channel's search bots about a subject
#   /blist [filter]    show the last results, optionally matching a word
#   /bget <number>     request one entry from that list
#
# Requesting is left as a separate, numbered step rather than something
# that follows automatically from a search: each file is a deliberate act,
# and whether you may have a given book is a question only you can answer.

include XChatRuby

class BookSearch < XChatRubyPlugin

  # Lines in a listing are the request commands themselves, and start with
  # the bot's name: "!SomeBot Author - Title.epub  ::INFO:: 1.2MB"
  ENTRY = /^\s*(![^\s]+\s+.+?)\s*$/

  # A listing arrives as an archive or a text file whose name says what it
  # is. Anything else that finishes downloading is left alone.
  LISTING = /search|result/i

  # A listing is worth nothing once it has been read, and they pile up in
  # the download directory otherwise. Set to false to keep them.
  CLEAN_UP_LISTINGS = true

  def initialize
    @entries = []
    @context = nil

    hook_command("bsearch", XCHAT_PRI_NORM, method(:cmd_search),
                 "Usage: /bsearch <terms>, ask the channel's search bots about a subject")
    hook_command("blist", XCHAT_PRI_NORM, method(:cmd_list),
                 "Usage: /blist [filter], show the last results, optionally matching a word")
    hook_command("bget", XCHAT_PRI_NORM, method(:cmd_get),
                 "Usage: /bget [number], request an entry from the last results, the first by default")

    hook_print("DCC RECV Complete", XCHAT_PRI_NORM, method(:on_download))

    puts_fmt "![c(blue)]BookSearch![c] loaded. /bsearch to look, /bget to fetch one."
    puts_fmt "![c(blue)]BookSearch![c] put the search bot in Preferences, DCC, trusted senders to stop being asked about its listings."
  end

  # ---------------------------------------------------------------- commands

  def cmd_search(words, words_eol, data)
    terms = words_eol[1].to_s.strip
    if terms.empty?
      puts "Usage: /bsearch <terms>"
      return XCHAT_EAT_ALL
    end

    # Results come back later and out of band, so remember where to report.
    @context = get_context
    @entries = []

    command("say @search #{terms}")
    puts_fmt "![c(blue)]BookSearch![c] asked for #{terms}. The listing arrives as a download."
    XCHAT_EAT_ALL
  end

  def cmd_list(words, words_eol, data)
    if @entries.empty?
      puts "No results yet. /bsearch <terms> first."
      return XCHAT_EAT_ALL
    end

    filter = words_eol[1].to_s.strip.downcase
    shown = 0

    @entries.each_with_index do |entry, i|
      next unless filter.empty? || entry.downcase.include?(filter)
      puts_fmt "![c(blue)]#{i + 1}![c] #{entry}"
      shown += 1
    end

    puts "#{shown} of #{@entries.size} shown." if shown != @entries.size
    XCHAT_EAT_ALL
  end

  def cmd_get(words, words_eol, data)
    if @entries.empty?
      puts "No results yet. /bsearch <terms> first."
      return XCHAT_EAT_ALL
    end

    # The first entry is the usual answer, so it is the default.
    index = words[1].to_s.strip.empty? ? 1 : words[1].to_i

    if index < 1 || index > @entries.size
      puts "Pick a number between 1 and #{@entries.size}. /blist to see them."
      return XCHAT_EAT_ALL
    end

    entry = @entries[index - 1]
    set_context(@context) if @context
    command("say #{entry}")
    puts_fmt "![c(blue)]BookSearch![c] requested: #{entry}"
    XCHAT_EAT_ALL
  end

  # --------------------------------------------------------------- downloads

  # There is deliberately no hook accepting the offer. The client decides
  # whether to ask you about a transfer before it announces the offer, so a
  # plugin sees it too late to prevent the question and only adds a second
  # acceptance. Naming the bot as a trusted sender is what skips it.
  #
  # Called for every completed download. The second field is a file URL, so
  # it names the file exactly wherever it was saved to.
  def on_download(words, data)
    name = words[0].to_s
    return XCHAT_EAT_NONE unless name =~ LISTING

    path = path_from_url(words[1].to_s)
    return XCHAT_EAT_NONE if path.nil? || !File.exist?(path)

    entries = read_listing(path)
    return XCHAT_EAT_NONE if entries.empty?

    @entries = entries
    set_context(@context) if @context
    puts_fmt "![c(blue)]BookSearch![c] #{entries.size} results. /blist to see them, /bget <n> to request one."

    discard_listing(path)

    XCHAT_EAT_NONE
  end

  private

  def path_from_url(url)
    return nil unless url.start_with?("file://")
    path = url.sub(%r{\Afile://}, "")
    path.gsub(/%([0-9A-Fa-f]{2})/) { $1.to_i(16).chr }
  end

  def read_listing(path)
    raw = File.read(path, mode: "rb")

    text =
      if raw.start_with?("PK\x03\x04")
        # A zip, whatever it is called: a listing that had to be renamed
        # arrives as "....zip.1" and no extension test would catch it.
        # There is no zip reader in the standard library, and unzip is
        # always present.
        `/usr/bin/unzip -p #{quote(path)} 2>/dev/null`
      elsif raw.start_with?("Rar!")
        puts "BookSearch: #{File.basename(path)} is a RAR, which cannot be read here. Unpack it yourself."
        return []
      else
        raw
      end

    text.force_encoding("UTF-8")
    text = text.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")

    text.split(/\r?\n/).map { |line| line[ENTRY, 1] }.compact
  rescue => error
    puts "BookSearch could not read #{path}: #{error.message}"
    []
  end

  # The listing has been read, and its only content was the list now held in
  # memory, so it is of no further use. Kept deliberately narrow: this runs
  # only for a file this plugin accepted and parsed, never for anything a
  # bot sent that was not a listing.
  def discard_listing(path)
    return unless CLEAN_UP_LISTINGS

    File.unlink(path)
    puts_fmt "![c(blue)]BookSearch![c] removed #{File.basename(path)}."
  rescue => error
    puts "BookSearch left #{File.basename(path)} in place: #{error.message}"
  end

  def quote(path)
    "'" + path.gsub("'", "'\\\\''") + "'"
  end
end

# Nothing is instantiated here on purpose. The bridge evaluates this file and
# then constructs every XChatRubyPlugin it finds in it, so creating one here
# as well would leave two: one holding the search results and another
# answering the commands.
