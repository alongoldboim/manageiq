class ContainerDeploymentService
  def all_data
    {
      :provision              => possible_provision_providers,
      :providers              => possible_providers_and_vms,
      :cloud_init_template_id => cloud_init_template_id,
    }.compact
  end

  def possible_provision_providers
    providers = ExtManagementSystem.includes(:vm_or_template).select do |m|
      m.instance_of?(ManageIQ::Providers::Amazon::CloudManager) || m.instance_of?(ManageIQ::Providers::Redhat::InfraManager)
    end
    providers.map do |provider|
      {:provider => provider, :templates => templates(provider.miq_templates)}
    end
  end

  def templates(templates)
    templates.map do |template|
      {
        :cpu       => template.cpu_total_cores,
        :memory    => template.mem_cpu,
        :disk_size => ApplicationController.helpers.number_to_human_size(template.disks.first ? template.disks.first.size : 0),
        :name      => template.name,
        :ems_id    => template.ems_id,
        :id        => template.id
      }
    end
  end

  def possible_providers_and_vms
    providers = ExtManagementSystem.includes(:vm_or_template).select do |m|
      m.kind_of?(ManageIQ::Providers::CloudManager) || m.kind_of?(ManageIQ::Providers::InfraManager)
    end
    providers.map do |provider|
      {:provider => provider, :vms => optional_vms(provider.vms)}
    end
  end

  def optional_vms(vms)
    optional_vms = vms.select { |vm| !vm.hardware.ipaddresses.empty? }
    optional_vms.map do |vm|
      {
        :cpu       => vm.hardware.cpu_total_cores,
        :memory    => vm.hardware.memory_mb,
        :disk_size => ApplicationController.helpers.number_to_human_size(vm.disks.first ? vm.disks.first.size : 0),
        :name      => vm.name,
        :ems_id    => vm.ems_id,
        :id        => vm.id
      }
    end
  end

  def cloud_init_template_id
    ContainerDeployment.add_basic_root_template
    CustomizationTemplate.find_by_name("Basic root pass template").id
  end
end