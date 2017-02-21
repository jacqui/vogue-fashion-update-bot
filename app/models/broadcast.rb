class Broadcast < ApplicationRecord
  has_and_belongs_to_many :users
  validates :title, presence: true, 
    unless: Proc.new { |b| b.template.blank? || b.template == 'text' }
  validates :link, presence: true, 
    unless: Proc.new { |b| b.template.blank? || b.template == 'text' }
  validates :button_text, presence: true, 
    unless: Proc.new { |b| b.template.blank? || b.template == 'text' }
  validates :image_url, presence: true, 
    unless: Proc.new { |b| b.template.blank? || b.template == 'text' }

  after_create do |broadcast|
    message_params = if broadcast.template.blank? || broadcast.template == 'text'
                       { message: { text: broadcast.text } }
                     elsif broadcast.template == 'image'
                       {
                         message: {
                           attachment: {
                             type: 'template',
                             payload: {
                               template_type: 'generic',
                               elements: [
                                 {
                                   title: broadcast.title,
                                   image_url: broadcast.image_url,
                                   default_action: {
                                     type: "web_url",
                                     url: broadcast.link
                                   },
                                   buttons:[
                                     {
                                       type: "web_url",
                                       url: broadcast.link,
                                       title: broadcast.button_text
                                     }
                                   ]      
                                 }
                               ]
                             }
                           }
                         }
                       }
                     else
                       raise "Unknown broadcast message type: #{broadcast.template}"
                     end

    User.all.each do |user|
      sent_at = Time.now
      combined_message_params = { recipient: { id: user.fbid } }.merge(message_params)
      begin
        Bot.deliver(combined_message_params, access_token: ENV['ACCESS_TOKEN'])
        user.broadcasts << broadcast
        user.last_message_sent_at = sent_at
        user.save!
      rescue => e
        puts e
      end
    end
  end
end
