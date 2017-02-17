class Subscription < ApplicationRecord
  belongs_to :brand
  belongs_to :user
  has_many :sent_messages

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
          content_to_send << c
        end
      elsif c.is_a?(Show)
        if SentMessage.where(show_id: c.id, user_id: user.id).where("sent_at IS NOT NULL").exists?
          puts "Already sent this show (#{c.id}) to user #{user.id}"
        else
          puts "New show (#{c.id}) for user #{user.id}"
          content_to_send << c
        end
      end
    end

    return content_to_send
  end
end
