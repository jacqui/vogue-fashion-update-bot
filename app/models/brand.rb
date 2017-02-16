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

end
