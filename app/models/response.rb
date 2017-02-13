class Response < ApplicationRecord
  # this can belong to a question or a possible answer
  belongs_to :possible_answer, optional: true
  belongs_to :question

  # some responses trigger a followup question
  belongs_to :next_question, class_name: "Question", optional: true

  validates :text, presence: true
  validates :question, presence: true
  validates :category, presence: true

  validates :category, inclusion: { in: %w(text articles_by_tag articles_top_stories runway_shows newsletter),
    message: "%{value} is not a valid category" }
  
end
