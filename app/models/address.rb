class Address < ApplicationRecord
  belongs_to :customer

  validates :street, :number, :neighborhood, :city, :state, :zip_code, presence: true
end
