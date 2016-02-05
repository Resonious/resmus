def come_here?
  proc do |event|
    text = event.message.text
    (text.downcase =~ /come.*(in|here)/) ||
    (text.downcase =~ /join/) ||
    (text.downcase =~ /get.*here/)
  end
end

def im_here
  [
    "Here", "Hi", "I'm here", "'Kay", "Alright", "I'm in",
    "Made it"
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
end
