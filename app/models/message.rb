class Message < ApplicationRecord
  def self.log_it(received_message)
    msg = Message.create(mid: message.messaging['message']['mid'], senderid: message.messaging['sender']['id'], seq: message.messaging['message']['seq'], sent_at: message.messaging['timestamp'], text: message.text)
    puts "Stored a record of this message: #{msg.id}"
    return msg
  end
end
