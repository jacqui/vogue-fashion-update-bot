class Broadcast < ApplicationRecord
  VALID_TEMPLATES = %w(text image video)

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
                     elsif %w(image video).include?(broadcast.template)
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

    recipients = if broadcast.internal_only?
                   User.where(cni_employee: true)
                 else
                   User.all
                 end

    recipients.each do |user|
      sent_at = Time.now
      combined_message_params = { recipient: { id: user.fbid } }.merge(message_params)
      begin
        Bot.deliver(combined_message_params, access_token: ENV['ACCESS_TOKEN'])

        user.broadcasts << broadcast
        user.last_message_sent_at = sent_at
        user.save!

        SentMessage.create!(user_id: user.id, text: content, push_notification: false, sent_at: Time.now)
      rescue => e
        puts e
      end
    end
  end

  def text?
    template.blank? || template == 'text'
  end

  def content
    return text if text?
    return title
  end
end
