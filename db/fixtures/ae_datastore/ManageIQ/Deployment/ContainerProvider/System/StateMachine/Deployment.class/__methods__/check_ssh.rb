def remove_deployment_master(hosts, master_ip)
  hosts.each do |host|
    if host.include? master_ip
      hosts.delete(host)
    end
  end
  hosts
end

def check_ssh
  begin
    $evm.log(:info, "**************** #{$evm.root['ae_state']} ****************")
    deployment_hosts = $evm.root['masters'] + $evm.root['nodes']
    deployment_hosts = remove_deployment_master(deployment_hosts, $evm.root['deployment_master'])
    $evm.root['agent_pid'], $evm.root['agent_socket'] = $evm.root['container_deployment'].create_ssh_agent
    $evm.root['container_deployment'].customize(:ssh_details => {:socket => sock, :pid => pid})
    $evm.log(:info, "tyring to ssh to: #{$evm.root['deployment_master']}")
    $evm.root['container_deployment'].check_connection($evm.root['deployment_master'], $evm.root['ssh_username'], deployment_hosts)
    $evm.root['ae_result'] = "ok"
    $evm.root['automation_task'].message = "#{$evm.root['ae_state']} was finished successfully"
  rescue => e
    $evm.log(:info, e)
    $evm.root['ae_result'] = "error"
    $evm.root['automation_task'].message = e
  end
end

check_ssh
