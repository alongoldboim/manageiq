module Api
  class ConditionsController < BaseController
    def create_resource(type, _id, data = {})
      assert_id_not_specified(data, type)
      data["expression"] = MiqExpression.new(data["expression"])
      super(type, _id, data)
    rescue => err
      raise BadRequestError, "Cant create condition: #{err}"
    end

    def edit_resource(type, id = nil, data = {})
      raise BadRequestError, "Must specify an id for editing a #{type} resource" unless id
      data["expression"] = MiqExpression.new(data["expression"]) if data["expression"]
      super(type, id, data)
    rescue => err
      raise BadRequestError, "Cant edit condition: #{err}"
    end
  end
end
