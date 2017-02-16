class Question < ApplicationRecord
  
  VALID_CATEGORIES = %w(text articles_by_tag top_stories runway_shows newsletter designers fyi)
  VALID_TYPES = %w(yes_no free choices_provided choices_provided_or_free no_response)

  validates :text, presence: true
  validates :sort_order, presence: true
  validates :type, presence: true
  validates :category, presence: true

  validates :category, inclusion: { in: VALID_CATEGORIES, message: "%{value} is not a valid category" }

  has_many :possible_answers,  -> { distinct.order("sort_order ASC") }
  accepts_nested_attributes_for :possible_answers, reject_if: lambda {|attributes| attributes['value'].blank?}
  has_one :response
  accepts_nested_attributes_for :response, reject_if: lambda {|attributes| attributes['text'].blank?}

  # use type column without STI
  self.inheritance_column = nil

  def self.starting
    where("sort_order = 1").first
  end

  def next
    next_questions = Question.where("sort_order > ? AND followup = ?", sort_order, false).order("sort_order ASC")
    if next_questions.any?
      next_questions.first
    end
  end

  def previous
    previous_questions = Question.where("sort_order < ? AND followup = ?", sort_order, false).order("sort_order DESC")
    if previous_questions.any?
      previous_questions.last
    end
  end

end
