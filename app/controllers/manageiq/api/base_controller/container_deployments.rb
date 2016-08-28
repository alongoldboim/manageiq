module ManageIQ
  module API
    class BaseController
      module ContainerDeployments
        def show_container_deployments
          validate_api_action
          if @req.c_id == "container_deployment_data"
            render_resource :container_deployments, :data => ContainerDeploymentService.new.all_data
          else
            show_generic
          end
        end

        def create_resource_container_deployments(_type, _id, data)
          deployment = ContainerDeployment.new
          deployment.create_deployment(data, @auth_user_obj)
        end

        def add_template_resource_container_deployments(_type, _id, data)
          provider = ExtManagementSystem.find_by_name(data.delete("name"))
          provider.container_deployments.destroy_all
          deployment = ContainerDeployment.create(:customizations => data.symbolize_keys)
          provider.container_deployments << deployment
        end
      end
    end
  end
end
