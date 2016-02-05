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

bot.message do |event|
  next unless event.message.mentions.blank?
end

bot.mention do |event|
  @last_channel = event.channel

  case event
  when come_here?
    user = bot.user(event.author.id)
    if voice_channel = user.voice_channel
      begin
        bot.voice_connect(voice_channel)
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

  else
    event.respond "Excuse me?"
  end
end

bot.ready { puts "READY" }

bot.run
