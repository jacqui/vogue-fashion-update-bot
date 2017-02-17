class Message < ApplicationRecord
  belongs_to :user, foreign_key: :fbid

  def self.log_it(received_message)
    mid = received_message.messaging['message']['mid'] rescue nil
    sid = received_message.messaging['sender']['id'] rescue nil
    seq = received_message['message']['seq'] rescue nil
    sent_at = received_message.messaging['timestamp'] rescue nil
    text = received_message.text rescue nil

    if mid && sid
      msg = Message.create(mid: mid, senderid: sid, seq: seq, sent_at: sent_at, text: text)
      puts "Stored a record of this message: #{msg.id}"
      return msg
    else
      puts received_message.inspect
      return nil
    end
  end
end
