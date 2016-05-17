def analyze_ansible_output(output)
  results = output.rpartition('PLAY RECAP ********************************************************************').last
  results = results.split("\r\n")
  results.shift
  passed = true
  results.each do |node_result|
    unless node_result.include?("unreachable=0") && node_result.include?("failed=0")
      passed                               = false
      $evm.root['ae_result']               = "error"
      $evm.root['automation_task'].message = "deployment failed"
      next
    end
    break unless passed
  end
end

$evm.log(:info, "********************** #{$evm.root['ae_state']} ******************************")
begin
  result = $evm.root['container_deployment'].perform_agent_commands($evm.root['deployment_master'], $evm.root['ssh_username'], ["ansible-playbook /usr/share/ansible/openshift-ansible/playbooks/byo/config.yml -i /usr/share/ansible/openshift-ansible/inventory.yaml"])
  $evm.root['ae_result'] = analyze_ansible_output(result[:stdout]) ? "ok" : "error"
rescue => e
  $evm.log(:info, e)
  $evm.root['ae_result'] = "error"
end
