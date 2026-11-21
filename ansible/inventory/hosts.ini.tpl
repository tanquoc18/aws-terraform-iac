[harbor]
harbor_server ansible_host=${harbor_public_ip} ansible_user=ubuntu

[k3s_server]
k3s_master ansible_host=${k3s_server_public_ip} ansible_user=ubuntu

[k3s_worker]
k3s_node1 ansible_host=${k3s_worker_public_ip} ansible_user=ubuntu

[k3s_cluster:children]
k3s_server
k3s_worker

[all:vars]
ansible_python_interpreter=/usr/bin/python3
ansible_ssh_private_key_file=~/.ssh/devops-lab-key.pem
