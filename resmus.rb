require 'cgi'
require 'active_support'
require 'active_support/core_ext'
require 'discordrb'
require_relative 'matchers_and_messages.rb'

class Config
  class << self
    attr_accessor :email
    attr_accessor :password
  end
end
require_relative 'config.rb'

if Config.email.blank? || Config.password.blank?
  puts "Please set Config.email and Config.password in 'config.rb'"
  exit
end

bot = Discordrb::Bot.new(Config.email, Config.password)

def remember(user, key, value)
  @memory[user.id] ||= {}
  @memory[user.id][key] = value
end

def recall(user, key)
  @memory[user.id].try(:[], key)
end

@downloading = false
def download_and_play_url(bot, channel_id, url)
  proc do
    begin
      @downloading = true
      unless /youtu\.?be/ =~ url
        bot.send_message(channel_id, "Hey wait, that's not a youtube URL..")
        next
      end

      unless /\/watch\?v=(?<filename>[\w-]+)/ =~ url
        bot.send_message(channel_id, "Ah, sorry, couldn't parse the URL")
        next
      end

      filename += ".ogg"
      filename = "download/#{filename}"
      if File.exists?(filename)
        bot.send_message(channel_id, "And we're playing!")
        @downloading = false
        bot.voice.stop_playing rescue nil
        bot.voice.play_file(filename)
        bot.voice.continue rescue nil
        next
      else
        bot.send_message(channel_id, "One sec, gotta download this")
        command = %(youtube-dl -o "#{filename.gsub(/\.ogg$/, '.%(ext)s')}" --extract-audio --audio-format vorbis #{url})
        puts command
        system(command)
        bot.send_message(channel_id, "Done!")
      end

      if File.exists?(filename)
        bot.send_message(channel_id, "Now we're playing!")
        @downloading = false
        bot.voice.stop_playing rescue nil
        bot.voice.play_file(filename)
        bot.voice.continue rescue nil
      else
        bot.send_message(channel_id, "Actually I fucked it up. Sorry.")
      end

    ensure
      @downloading = false
    end
  end
end

def download_and_play_title(bot, channel_id, title)
  proc do
    begin
      @downloading = true
      filename = title.gsub(/\s+/, '-') + ".ogg"
      filename = "download/#{filename}"
      if File.exists?(filename)
        bot.send_message(channel_id, "And we're playing!")
        @downloading = false
        bot.voice.stop_playing rescue nil
        bot.voice.play_file(filename)
        bot.voice.continue rescue nil
        next
      else
        bot.send_message(channel_id, "I'll see what I can find")
        command = %(youtube-dl -o "#{filename.gsub(/\.ogg$/, '.%(ext)s')}" --playlist-items 1 --extract-audio --audio-format vorbis "https://youtube.com/results?search_query=#{CGI.escape title}")
        puts command
        system(command)
        bot.send_message(channel_id, "Okay..")
      end

      if File.exists?(filename)
        bot.send_message(channel_id, "Hopefully this is what you were after!")
        @downloading = false
        bot.voice.stop_playing rescue nil
        bot.voice.play_file(filename)
        bot.voice.continue rescue nil
      else
        bot.send_message(channel_id, "Couldn't find anything")
      end

    ensure
      @downloading = false
    end
  end
end

handle_event = lambda do |event, user, is_private|
  if @downloading
    event.respond downloading_something
    next
  end

  case event
  when come_here?(@conversation[user.id])
    if voice_channel = user.voice_channel
      begin
        bot.voice_connect(voice_channel)

        if @conversation[user.id] == :asked_if_i_should_join_voice
          @conversation[user.id] = nil


          event.respond im_here
          if url = recall(user, :play_url)
            Thread.new(&download_and_play_url(bot, event.channel.id, url))
          elsif title = recall(user, :play_title)
            Thread.new(&download_and_play_title(bot, event.channel.id, title))
          end
        end
      rescue StandardError => e
        puts "==== Failed to do voice! #{e.class}: #{e.message} ===="
        puts e.backtrace
        puts "==========================="
      end

      unless bot.voice
        event.respond im_here

        if @cant_do_voice
          event.respond cant_do_voice
        else
          event.respond "Oops, looks like there was an error initializing my audio. Sorry"
          @cant_do_voice = true
        end
      end
    else
      event.respond youre_not_in_a_voice_channel
    end

  when play_url?
    if /(?<url>http\S+)/ =~ event.message.text
      remember(user, :play_url, url)

      if bot.voice.nil? || bot.instance_variable_get(:@voice_channel).id != user.voice_channel.try(:id)
        event.respond im_not_in_a_voice_channel(user)
        @conversation[user.id] = :asked_if_i_should_join_voice
      else
        Thread.new(&download_and_play_url(bot, event.channel.id, url))
      end
    else
      event.respond missed_play(user)
    end

  when play?
    /^.*(?<play>play)\s+(?<title>.+)$/ =~ event.message.text
    remember(user, :play_title, title)

    if bot.voice.nil? || bot.instance_variable_get(:@voice_channel).id != user.voice_channel.try(:id)
      event.respond im_not_in_a_voice_channel(user)
      @conversation[user.id] = :asked_if_i_should_join_voice
    else
      Thread.new(&download_and_play_title(bot, event.channel.id, title))
    end

  when stop?
    if bot.voice
      bot.voice.stop_playing
      if event.message.text =~ /stfu|shut/
        event.respond "rude"
      else
        event.respond "ok"
      end

      if is_private && @last_channel
        bot.send_message(@last_channel.id, "#{event.author.mention} just told me to #{event.message.text}")
      end
    end

  when pause?
    if bot.voice
      bot.voice.pause
      event.respond "ok"
    end

    if is_private && @last_channel
      bot.send_message(@last_channel.id, "#{event.author.mention} just told me to #{event.message.text}")
    end

  when continue?
    if bot.voice
      bot.voice.continue
      event.respond "resuming"
    end

  when help?
    if @conversation[user.id] == :just_helped
      event.respond "What more do you want to know, #{user.mention}?!"
    else
      event.respond "@Mention me with 'play whatever' and I'll search youtube for 'whatever'. "\
        "@Mention me with 'stop' or whatever and I'll stop playing music.' "\
        "Instead of @mentioning me, you can just chat me privately. That works too. "\
        "You can also give me urls."
      @conversation[user.id] = :just_helped
    end

  else
    event.respond "Excuse me?"
  end
end

@conversation = {}
@memory = {}
bot.mention do |event|
  @last_channel = event.channel
  user = bot.user(event.author.id)

  # puts "Conversation with #{user.name} is at #{@conversation[user.id].inspect}"
  handle_event.call(event, user, false)
end

bot.message(private: true) do |event|
  user = bot.user(event.author.id)
  handle_event.call(event, user, true)
end

bot.message(private: false) do |event|
  if who?(event)
    event.respond im_a_bot(event.author, event.message.text)
  elsif @conversation[event.author.id] && event.message.mentions.blank?
    handle_event.call(event, bot.user(event.author.id), false)
  end
end

bot.ready { puts "READY" }

bot.run
