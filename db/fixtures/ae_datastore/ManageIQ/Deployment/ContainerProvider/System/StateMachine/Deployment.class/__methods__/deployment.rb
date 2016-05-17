$evm.log(:info, "********************** #{$evm.root['ae_state']} ******************************")
begin
  $evm.root['container_deployment'] = $evm.vmdb(:container_deployment).find(
    $evm.root['automation_task'].automation_request.options[:attrs][:deployment_id])
  result = $evm.root['container_deployment'].run_playbook_command($evm.root['deployment_master'], $evm.root['ssh_username'], "ansible-playbook /usr/share/ansible/openshift-ansible/playbooks/byo/config.yml -i /usr/share/ansible/openshift-ansible/inventory.yaml 1> /tmp/openshift-ansible.log.1 2> /tmp/openshift-ansible.log.2 < /dev/null")
  if result[:finished]
    $evm.root['ae_result'] = $evm.root['container_deployment'].analyze_ansible_output(result[:stdout]) ? "ok" : "error"
  else
    $evm.log(:info, "*********  deployment playbook is runing waiting for it to finish ************")
    $evm.root['ae_result']         = 'retry'
    $evm.root['ae_retry_interval'] = '1.minute'
  end
rescue => e
  $evm.log(:info, e)
  $evm.root['ae_result'] = "error"
end
