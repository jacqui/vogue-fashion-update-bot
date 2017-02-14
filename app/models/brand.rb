class Brand < ApplicationRecord
  has_many :notifications
  has_many :shows
  has_many :subscriptions
  has_many :users, through: :subscriptions
  has_many :possible_answers

  validates :slug, uniqueness: true

  def self.default_scope
    order("title ASC")
  end

  def articles
    brand_articles = Article.where(tag: slug)
    puts "#{brand_articles.size} articles found"
    brand_articles
  end
end
