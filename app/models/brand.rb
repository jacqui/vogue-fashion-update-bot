class Brand < ApplicationRecord
  has_many :notifications
  has_many :shows
  has_many :subscriptions
  has_many :users, through: :subscriptions
  has_many :possible_answers
  has_many :articles

  validates :slug, uniqueness: true

  def self.default_scope
    order("title ASC")
  end

  def latest_content
    latest_shows = shows.order("date_time DESC").limit(4)
    puts " (brand ##{id}) shows: #{latest_shows.size}"
    latest_articles = articles.order("created_at DESC").limit(4)
    puts " (brand ##{id}) articles: #{latest_articles.size}"
    return latest_shows + latest_articles
  end
end
