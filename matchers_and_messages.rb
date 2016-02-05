def come_here?(conversation)
  proc do |event|
    text = event.message.text
    (text.downcase =~ /come.*(in|here)/) ||
    (text.downcase =~ /join/)            ||
    (text.downcase =~ /get.*here/)       ||
    (
      conversation == :asked_if_i_should_join_voice &&
      text.downcase =~ /yes|yeah|sure|alright|okay|yes|do\s+it|pl[sz]|ye|ys|yeh|yah|ya/
    )
  end
end

def im_here
  [
    "Here", "Hi", "I'm here", "'Kay", "Alright", "I'm in",
    "'Kay", "Cool", "Here I am", "Okay"
  ]
    .sample
end

def youre_not_in_a_voice_channel
  [
    "You're not in a voice channel",
    "You're not in a voice channel, dude",
    "Join you where?!",
    "Where?", "No", "I can't..", "What"
  ]
    .sample
end

def cant_do_voice
  [
    "Remember though, my audio is screwed up so I can't play music",
    "No music, though", "Won't play any music, though",
    "No point in me being in this voice channel", "Whatever",
    "Tell @Resonious to fix my audio"
  ]
    .sample
end

def stop?
  proc do |event|
    text = event.message.text
    text =~ /stop|shut.+up|stfu|gtfo|die/
  end
end

def pause?
  proc do |event|
    event.message.text =~ /pause|wait|time\s+out/
  end
end

def play_url?
  proc do |event|
    text = event.message.text
    text =~ /https?:\/\//
  end
end

def im_not_in_a_voice_channel(user)
  [
    "#{user.mention} Would you like me to join your voice channel?",
    "#{user.mention} I'm not in a voice channel, should I join yours?",
    "Should I join your voice channel #{user.mention}?",
    "#{user.mention} want me to join your voice channel?"
  ]
    .sample
end

def missed_play(user)
  [
    "#{user.mention} sorry, missed that",
    "#{user.mention} if your url has whitespace in it, I probably can't read it. Sorry",
    "#{user.mention} couldn't read your url for some reason"
  ]
    .sample
end

def play?
  proc do |event|
    text = event.message.text
    text.downcase =~ /play/
  end
end

def help?
  proc do |event|
    event.message.text =~ /help|wtf/
  end
end
