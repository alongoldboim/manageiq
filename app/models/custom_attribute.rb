class CustomAttribute < ApplicationRecord
  belongs_to :resource, :polymorphic => true
  serialize :serialized_value

  def value=(value)
    self.serialized_value = value
  end

  def stored_on_provider?
    source == "VC"
  end
end
