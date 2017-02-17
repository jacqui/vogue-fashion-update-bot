class Response < ApplicationRecord
  # this can belong to a question or a possible answer
  belongs_to :possible_answer, optional: true
  belongs_to :question, optional: true

  # some responses trigger a followup question
  belongs_to :next_question, class_name: "Question", optional: true

  validates :category, presence: true

  validates :category, inclusion: { in: %w(top_stories designers),
    message: "%{value} is not a valid category" }
  
end
