class Content < ApplicationRecord
  validates :title, uniqueness: true, presence: true
  validates :label, uniqueness: true, presence: true
  validates :body, presence: true
end
