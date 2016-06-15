require 'net/ssh'
require 'fileutils'

class NetSshAgentService
  attr_reader :pid
  attr_reader :sock

  def initialize(agent_socket, ssh_private_key)
    FileUtils.mkdir_p(File.dirname(agent_socket))
    agent_details = `ssh-agent -a #{agent_socket}`
    @sock         = agent_details.split("=")[1].split(" ")[0].chop
    @pid          = agent_details.split("=")[2].split(" ")[0].chop
    IO.popen({"SSH_AUTH_SOCK" => @sock, "SSH_AGENT_PID" => @pid}, ["ssh-add", "-"], :mode => 'w') do |f|
      f.puts(ssh_private_key)
      if $?.to_i != 0
        raise "Couldn't add key to agent"
      end
    end
  end

  def ssh_exec!(ssh, command, username, ip)
    stdout_data, stderr_data = "", ""
    exit_code, exit_signal   = nil, nil

    ssh.open_channel do |channel|
      channel.exec("ssh -A -o 'StrictHostKeyChecking no' -t -t #{username}@#{ip} " \
                 + command) do |_, success|
        raise StandardError, "Command \"#{command}\" was unable to execute" unless success

        channel.on_data do |_, data|
          stdout_data += data
        end

        channel.on_extended_data do |_, _, data|
          stderr_data += data
        end

        channel.on_request("exit-status") do |_, data|
          exit_code = data.read_long
        end

        channel.on_request("exit-signal") do |_, data|
          exit_signal = data.read_long
        end
      end
    end
    ssh.loop
    {
      :stdout      => stdout_data,
      :stderr      => stderr_data,
      :exit_code   => exit_code,
      :exit_signal => exit_signal
    }
  end

  def perform_commands(ip, username, commands)
    result = nil
    Net::SSH.start(ip, username, :paranoid => false, :forward_agent => true, :agent_socket_factory => -> { UNIXSocket.open(@sock) }) do |ssh|
      commands.each do |cmd|
        result           = ssh_exec!(ssh, cmd, username, ip)
        result[:lastcmd] = cmd
        unless result[:exit_code] == 0
          break
        end
      end
    end
    result
  end

  def check_connection(ip, username, sub_ips)
    connection_success = true
    unreachable_hosts  = []
    Net::SSH.start(ip, username, :paranoid => false, :forward_agent => true, :agent_socket_factory => -> { UNIXSocket.open(@sock) }) do |ssh|
      sub_ips.each do |sub_ip|
        result = ssh.exec!("ssh -o 'StrictHostKeyChecking no' #{username}@#{sub_ip} echo $?")
        unless result.include? "0\n"
          connection_success = false
          unreachable_hosts << host
        end
      end
    end
    [connection_success, unreachable_hosts]
  end
end
