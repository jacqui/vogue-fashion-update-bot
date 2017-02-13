class PossibleAnswer < ApplicationRecord
  belongs_to :brand, optional: true
  belongs_to :question
  has_one :response

  def appropriate_response
    # free-text questions don't have any possible answers, so look up the
    # response on the question itself.
    if question.type == "free" || question.type == "choices_provided_or_free"
      question.response

    # otherwise, respond with this answer's text (e.g. a yes/no question)
    else
      response
    end
  end
end
