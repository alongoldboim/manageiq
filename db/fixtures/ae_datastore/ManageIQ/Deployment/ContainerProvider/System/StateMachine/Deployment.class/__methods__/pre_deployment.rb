LOCAL_BOOK = 'local_book.yaml'.freeze
REPO_URL   = "https://copr.fedorainfracloud.org/coprs/maxamillion/origin-next/repo/epel-7/maxamillion-origin-next-epel-7.repo".freeze

def handle_rhel_subscriptions(commands)
commands.unshift("subscription-manager repos --disable=\"*\"",
                   "subscription-manager repos --enable=\"rhel-7-server-rh-common-rpms\" --enable=\"rhel-7-server-rpms\" --enable=\"rhel-7-server-extras-rpms\" --enable=\"rhel-7-server-ose-3.2-rpms\"")
  $evm.root['container_deployment'].perform_scp($evm.root['deployment_master'], $evm.root['ssh_username'], "rhel_subscribe_inventory.yaml", "rhel_subscribe_inventory.yaml")

  commands.push("sudo mv ~/rhel_subscribe_inventory.yaml /usr/share/ansible/openshift-ansible/")
end

def pre_deployment
  deployment = $evm.root['container_deployment']
  commands   = ['sudo yum install -y ansible-1.9.4',
                'sudo yum install -y openshift-ansible openshift-ansible-playbooks pyOpenSSL',
                "sudo mv ~/inventory.yaml /usr/share/ansible/openshift-ansible/"
  ]
  $evm.log(:info, "********************** #{$evm.root['ae_state']} ***************************")
  $evm.root['container_deployment'].perform_scp($evm.root['deployment_master'], $evm.root['ssh_username'], "inventory.yaml", "inventory.yaml")
  release = deployment.perform_agent_commands($evm.root['deployment_master'], $evm.root['ssh_username'], ["cat /etc/redhat-release"])[:stdout]
  if release.include?("CentOS")
    commands.unshift("sudo yum install epel-release -y",
                     "sudo curl -o /etc/yum.repos.d/maxamillion-origin-next-epel-7.repo #{REPO_URL}")
  elsif release.include?("Red Hat Enterprise Linux") &&
        !$evm.root['automation_task'].automation_request.options[:attrs][:containerized]
    commands = handle_rhel_subscriptions(commands)
    $evm.root['rhsub_user'] = $evm.root['automation_task'].automation_request.options[:attrs][:rhsub_user]
    $evm.root['rhsub_pass'] = $evm.root['automation_task'].automation_request.options[:attrs][:rhsub_pass]
    $evm.root['rhsub_pool'] = $evm.root['automation_task'].automation_request.options[:attrs][:rhsub_sku]

    deployment.perform_agent_commands($evm.root['deployment_master'], $evm.root['ssh_username'], ["subscription-manager register --username=#{$evm.root['rhsub_user']}  --password=#{$evm.root['rhsub_pass']}"])
    pool_id = deployment.perform_agent_commands($evm.root['deployment_master'], $evm.root['ssh_username'], ["subscription-manager list --available --matches=#{$evm.root['rhsub_sku']} --pool-only"])[:stdout].split("\n").first.delete("\r")
    deployment.perform_agent_commands($evm.root['deployment_master'], $evm.root['ssh_username'], ["subscription-manager attach --pool=#{pool_id}"])
  end
  deployment.perform_agent_commands($evm.root['deployment_master'], $evm.root['ssh_username'], commands)
   if commands.include?("sudo mv ~/rhel_subscribe_inventory.yaml /usr/share/ansible/openshift-ansible/")
     rhel_subscribe_cmd = "ansible-playbook /usr/share/ansible/openshift-ansible/playbooks/byo/rhel_subscribe.yml -i "\
                       "/usr/share/ansible/openshift-ansible/rhel_subscribe_inventory.yaml 1> /tmp/openshift-ansible.log.1 2> /tmp/openshift-ansible.log.2 < /dev/null"
     deployment.run_playbook_command($evm.root['deployment_master'], $evm.root['ssh_username'], rhel_subscribe_cmd)
     $evm.root['ae_result']         = 'retry'
     $evm.root['ae_retry_interval'] = '1.minute'
   else
     $evm.root['ae_result']               = "ok"
     $evm.root['automation_task'].message = "#{$evm.root['ae_state']} was finished successfully"
   end

rescue => e
  $evm.log(:info, e)
  $evm.root['ae_result']               = "error"
  $evm.root['automation_task'].message = e
end

$evm.root['container_deployment'] = $evm.vmdb(:container_deployment).find(
  $evm.root['automation_task'].automation_request.options[:attrs][:deployment_id])

if $evm.root['container_deployment'].playbook_running?
  rhel_subscribe_cmd = "ansible-playbook /usr/share/ansible/openshift-ansible/playbooks/byo/rhel_subscribe.yml -i "\
                       "/usr/share/ansible/openshift-ansible/rhel_subscribe_inventory.yaml 1> /tmp/openshift-ansible.log.1 2> /tmp/openshift-ansible.log.2 < /dev/null"
  result = $evm.root['container_deployment'].run_playbook_command($evm.root['deployment_master'], $evm.root['ssh_username'], rhel_subscribe_cmd)
  if result[:finished]
    $evm.root['ae_result'] = $evm.root['container_deployment'].analyze_ansible_output(result[:stdout]) ? "ok" : "error"
  else
    $evm.log(:info, "*********  pre-deployment playbook is runing waiting for it to finish ************")
    $evm.root['ae_result']         = 'retry'
    $evm.root['ae_retry_interval'] = '1.minute'
  end
else
  pre_deployment
end
