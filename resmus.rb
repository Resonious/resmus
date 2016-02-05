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

def download_and_play_url(bot, channel_id, url)
  proc do
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
      bot.voice.play_file(filename)
      next
    else
      bot.send_message(channel_id, "One set, gotta download this")
      command = %(youtube-dl -o "#{filename.gsub(/\.mp3$/, '.%(ext)s')}" --extract-audio #{url})
      puts command
      system(command)
      bot.send_message(channel_id, "Done!")
    end

    if File.exists?(filename)
      bot.send_message(channel_id, "Now we're playing!")
      bot.voice.play_file(filename)
    else
      bot.send_message(channel_id, "Actually I fucked it up. Sorry.")
    end
  end
end

bot.message do |event|
  next unless event.message.mentions.blank?
end

@conversation = {}
@memory = {}
bot.mention do |event|
  @last_channel = event.channel
  user = bot.user(event.author.id)

  puts "Conversation's at #{@conversation[user.id].inspect}"
  case event
  when come_here?(@conversation[user.id])
    if voice_channel = user.voice_channel
      begin
        bot.voice_connect(voice_channel)

        if @conversation[user.id] == :asked_if_i_should_join_voice
          @conversation[user.id] = nil
          Thread.new(&download_and_play_url(bot, event.channel.id, recall(user, :play_url)))
        end
      rescue StandardError => e
        puts "==== Failed to do voice! #{e.class}: #{e.message} ===="
        puts e.backtrace
        puts "==========================="
      end

      event.respond im_here

      unless bot.voice
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

  else
    event.respond "Excuse me?"
  end
end

bot.ready { puts "READY" }

bot.run
