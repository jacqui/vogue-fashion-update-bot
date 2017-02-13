class Message < ApplicationRecord
  def self.log_it(received_message)
    msg = Message.create(mid: received_message.messaging['message']['mid'], senderid: received_message.messaging['sender']['id'], seq: received_message.messaging['message']['seq'], sent_at: received_message.messaging['timestamp'], text: received_message.text)
    puts "Stored a record of this message: #{msg.id}"
    return msg
  end
end
