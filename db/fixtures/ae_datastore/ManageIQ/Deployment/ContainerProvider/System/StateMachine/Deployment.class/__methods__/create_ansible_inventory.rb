INVENTORY_FILE = 'inventory.yaml'.freeze
RHEL_SUBSCRIBE_INVENTORY = 'rhel_subscribe_inventory.yaml'.freeze

def create_ansible_inventory_file(subscribe = false)
  if subscribe
    template = $evm.root['rhel_subscribe_inventory']
    inv_file_path = RHEL_SUBSCRIBE_INVENTORY
  else
    $evm.log(:info, "********************** #{$evm.root['ae_state']} ***************************")
    template = $evm.root['inventory']
    inv_file_path = INVENTORY_FILE
  end
  begin
    $evm.log(:info, "creating #{inv_file_path}")
    File.open(inv_file_path, 'w') do |f|
      f.write(template)
    end
    $evm.root['ae_result'] = "ok"
    $evm.root['automation_task'].message = "successfully created #{inv_file_path}"
  rescue StandardError => e
    $evm.root['ae_result'] = "error"
    $evm.root['automation_task'].message = "failed to create #{inv_file_path}: " + e
  end
end

create_ansible_inventory_file
# check if an additional inventory file is needed for handling rhel subscriptions
begin
  create_ansible_inventory_file(true) if $evm.root['container_deployment'].perform_agent_commands($evm.root['deployment_master'], $evm.root['ssh_username'], ["cat /etc/redhat-release"])[:stdout].include?("Red Hat Enterprise Linux")
rescue
  $evm.root['ae_result'] = "error"
  $evm.root['automation_task'].message = "Cannot connect to deployment master " \
                                         "(#{$evm.root['deployment_master']}) via ssh"
end
$evm.log(:info, "State: #{$evm.root['ae_state']} | Result: #{$evm.root['ae_result']} "\
         "| Message: #{$evm.root['automation_task'].message}")
