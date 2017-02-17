class Subscription < ApplicationRecord
  belongs_to :brand
  belongs_to :user

  def self.default_scope
    order("user_id ASC")
  end

  def find_content_to_send
    return [] unless brand.present? && user.present?

    latest_content = brand.latest_content
    content_to_send = []
    latest_content.each do |c|
      if c.is_a?(Article)
        if SentMessage.where(article_id: c.id, user_id: user.id).where("sent_at IS NOT NULL").exists?
          puts "Already sent this article (#{c.id}) to user #{user.id}"
        else
          puts "New article (#{c.id}) for user #{user.id}"
          SentMessage.create(article_id: c.id, user_id: user.id, brand_id: brand.id, sent_at: Time.now, text: c.title)
          content_to_send << c
        end
      elsif c.is_a?(Show)
        if SentMessage.where(show_id: c.id, user_id: user.id).where("sent_at IS NOT NULL").exists?
          puts "Already sent this show (#{c.id}) to user #{user.id}"
        else
          puts "New show (#{c.id}) for user #{user.id}"
          SentMessage.create(show_id: c.id, user_id: user.id, brand_id: brand.id, sent_at: Time.now, text: c.title)
          content_to_send << c
        end
      end
    end

    return content_to_send
  end
end
