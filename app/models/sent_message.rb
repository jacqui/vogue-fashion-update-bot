class SentMessage < ApplicationRecord
  belongs_to :article, optional: true
  belongs_to :user
  belongs_to :brand, optional: true
  belongs_to :show, optional: true

  def reason
    return "Article matched tag" if article.present?
    return "Runway show" if show.present?
    return "General"
  end
end
