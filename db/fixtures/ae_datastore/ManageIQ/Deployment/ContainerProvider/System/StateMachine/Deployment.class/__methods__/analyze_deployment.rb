def analyze_deployment
  $evm.log(:info, "********************** #{$evm.root['ae_state']} ***************************")
  if $evm.root['deployment_method'] == "provision"
    $evm.root['ae_next_state'] = "provision"
  else
    $evm.root['ae_next_state'] = "check_ssh"
    $evm.root['masters'] = $evm.root['automation_task'].automation_request.options[:attrs][:masters]
    $evm.root['nodes'] = $evm.root['automation_task'].automation_request.options[:attrs][:nodes]
    $evm.root['deployment_master'] = $evm.root['automation_task'].automation_request.options[:attrs][:deployment_master]
  end
  provider_name = $evm.root['automation_task'].automation_request.options[:attrs][:provider_name]
  $evm.set_state_var(:provider_name, provider_name)
  $evm.root['container_deployment'] = $evm.vmdb(:container_deployment).find(
    $evm.root['automation_task'].automation_request.options[:attrs][:deployment_id])
  ssh_user = $evm.root['container_deployment'].ssh_user
  $evm.set_state_var(:ssh_user, ssh_user)
  $evm.root['container_deployment'].add_automation_task($evm.root['automation_task'])
  $evm.root['ae_result'] = "ok"
  $evm.root['automation_task'].message = "deployment type - #{$evm.root['deployment_method']}"
  $evm.log(:info, "State: #{$evm.root['ae_state']} | Result: #{$evm.root['ae_result']} "\
           "| Message: #{$evm.root['automation_task'].message}")
end

begin
  analyze_deployment
rescue => err
  $evm.log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  $evm.root['ae_result'] = 'error'
  $evm.root['ae_reason'] = "Error: #{err.message}"
  exit MIQ_ERROR
end
