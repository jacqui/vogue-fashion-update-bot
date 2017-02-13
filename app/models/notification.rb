class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :article, optional: true
  belongs_to :brand, optional: true
  belongs_to :show, optional: true


end
