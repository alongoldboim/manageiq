LOCAL_BOOK = 'local_book.yaml'.freeze
REPO_URL   = "https://copr.fedorainfracloud.org/coprs/maxamillion/origin-next/repo/epel-7/maxamillion-origin-next-epel-7.repo".freeze

def handle_rhel_subscriptions(commands)
  # need to add rhel-7-server-ose-3.1-rpms
  commands.unshift("subscription-manager repos --disable=\"*\"",
                   "subscription-manager repos --enable=\"rhel-7-server-rh-common-rpms\" --enable=\"rhel-7-server-rpms\" --enable=\"rhel-7-server-extras-rpms\"")
  system({"SSH_AUTH_SOCK" => $evm.root['agent_socket'], "SSH_AGENT_PID" => $evm.root['agent_pid']}, "scp -o 'StrictHostKeyChecking no' rhel_subscribe_inventory.yaml #{$evm.root['ssh_username']}@#{$evm.root['deployment_master']}:~/")
  rhel_subscribe_cmd = "ansible-playbook /usr/share/ansible/openshift-ansible/playbooks/byo/rhel_subscribe.yml -i "\
                       "/usr/share/ansible/openshift-ansible/rhel_subscribe_inventory.yaml"
  commands.push("sudo mv ~/rhel_subscribe_inventory.yaml /usr/share/ansible/openshift-ansible/", rhel_subscribe_cmd)
end

# need to remove
def create_puddle_repo
  File.open("temp.repo", "w") do |f|
    f.write("[temp]\nname=alontemp\nbaseurl=http://download.eng.bos.redhat.com/rcm-guest/puddles/RHAOS/AtomicOpenShift/3.2/arbitrary-yaml/x86_64/os/\nenabled=1\ngpgcheck=0")
  end
  system({"SSH_AUTH_SOCK" => $evm.root['agent_socket'], "SSH_AGENT_PID" => $evm.root['agent_pid']}, "scp -o 'StrictHostKeyChecking no' temp.repo #{$evm.root['ssh_username']}@#{$evm.root['deployment_master']}:/etc/yum.repos.d/")
end

def pre_deployment
  deployment = $evm.root['container_deployment']
  commands   = ['sudo yum install -y ansible-1.9.4',
                'sudo yum install -y openshift-ansible openshift-ansible-playbooks pyOpenSSL',
                "sudo mv ~/inventory.yaml /usr/share/ansible/openshift-ansible/"
  ]
  $evm.log(:info, "********************** #{$evm.root['ae_state']} ***************************")
  system({"SSH_AUTH_SOCK" => $evm.root['agent_socket'], "SSH_AGENT_PID" => $evm.root['agent_pid']}, "scp -o 'StrictHostKeyChecking no' inventory.yaml #{$evm.root['ssh_username']}@#{$evm.root['deployment_master']}:~/")
  release = deployment.perform_agent_commands($evm.root['deployment_master'], $evm.root['ssh_username'], ["cat /etc/redhat-release"])[:stdout]
  if release.include?("CentOS")
    commands.unshift("sudo yum install epel-release -y",
                     "sudo curl -o /etc/yum.repos.d/maxamillion-origin-next-epel-7.repo #{REPO_URL}")
  elsif release.include?("Red Hat Enterprise Linux") &&
        !$evm.root['automation_task'].automation_request.options[:attrs][:containerized]
    commands = handle_rhel_subscriptions(commands)
    deployment.perform_agent_commands($evm.root['deployment_master'], $evm.root['ssh_username'], ["subscription-manager register --username=#{$evm.root['rhsub_user']}  --password=#{$evm.root['rhsub_pass']}"])
    pool_id = deployment.perform_agent_commands($evm.root['deployment_master'], $evm.root['ssh_username'], ["subscription-manager list --available --matches=#{$evm.root['rhsub_sku']} --pool-only"])[:stdout].split("\n").first.delete("\r")
    deployment.perform_agent_commands($evm.root['deployment_master'], $evm.root['ssh_username'], ["subscription-manager attach --pool=#{pool_id}"])
    # need to remove
    create_puddle_repo
  end
  deployment.perform_agent_commands($evm.root['deployment_master'], $evm.root['ssh_username'], commands)
  $evm.root['ae_result']               = "ok"
  $evm.root['automation_task'].message = "#{$evm.root['ae_state']} was finished successfully"
rescue => e
  $evm.log(:info, e)
  $evm.root['ae_result']               = "error"
  $evm.root['automation_task'].message = e
end

pre_deployment
