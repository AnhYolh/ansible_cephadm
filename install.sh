!/bin/bash

############################### Create File Host, IP ###############################
if [ ! -f "ip_client.txt" ]; then
    touch ip_client.txt
    echo "File ip_client.txt đã được tạo."
fi

echo "Nhập thông tin IP clients (nhập xong nhấn Ctrl+D để kết thúc):"
cat > ip_client.txt

if [ ! -f "host_client.txt" ]; then
    touch host_client.txt
    echo "File host_client.txt đã được tạo."
fi

echo "Nhập thông tin host clients (nhập xong nhấn Ctrl+D để kết thúc):"
cat > host_client.txt

echo "Thông tin đã được lưu vào ip_client.txt và host_client.txt."

############################### Tạo file Inventory ###############################
if [ ! -f "ip_client.txt" ] || [ ! -f "host_client.txt" ]; then
  echo "File ip_client.txt hoặc host_client.txt không tồn tại!"
  exit 1
fi

echo "[ceph_data]" > inventory.ini

paste -d' ' host_client.txt ip_client.txt | while read host ip; do
  if [[ $host == ceph* ]]; then
    echo "$host ansible_host=$ip" >> inventory.ini
  fi
done

echo -e "\n[ceph_RGW]" >> inventory.ini

paste -d' ' host_client.txt ip_client.txt | while read host ip; do
  if [[ $host == rgw* ]]; then
    echo "$host ansible_host=$ip" >> inventory.ini
  fi
done

echo "Inventory file has been generated: inventory.ini"

############################### Copy ssh-keygen to all host client ###############################
if [ ! -f ~/.ssh/id_rsa ]; then
    echo "Generating SSH key..."
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
else
    echo "SSH key already exists."
fi

NODES=()
if [ ! -f "ip_client.txt" ]; then
    echo "File ip_client.txt không tồn tại!"
    exit 1
fi

sed -i -e '$a\' ip_client.txt

NODES=()
while IFS= read -r line; do
    if [[ -n "$line" ]]; then
        NODES+=("$line")
    fi
done < ip_client.txt

USER="root"
PASSWORD="Tuananh2001."

for NODE in "${NODES[@]}"; do
    echo "Attempting to copy SSH key to $NODE..."

    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$USER@$NODE" exit 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "Cannot connect to $NODE. Skipping."
        continue
    fi

    sshpass -p "$PASSWORD" ssh-copy-id -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa.pub "$USER@$NODE"
    if [ $? -eq 0 ]; then
        echo "SSH key successfully copied to $NODE."
    else
        echo "Failed to copy SSH key to $NODE."
    fi

done

echo "SSH key generation and copy completed."

##Run Ansible
if ! command -v ansible-playbook &> /dev/null; then
    echo "Ansible chưa được cài đặt. Cài đặt..."

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "$ID" == "ubuntu" || "$ID" == "debian" ]]; then
            sudo apt update
            sudo apt install -y ansible
        elif [[ "$ID" == "centos" || "$ID" == "rhel" || "$ID" == "fedora" ]]; then
            sudo yum install -y epel-release
            sudo yum install -y ansible
        else
            echo "Hệ điều hành không được hỗ trợ tự động cài đặt Ansible."
            exit 1
        fi
    else
        echo "Không nhận diện được hệ điều hành. Vui lòng cài đặt Ansible thủ công."
        exit 1
    fi

    if ! command -v ansible-playbook &> /dev/null; then
        echo "Cài đặt Ansible thất bại. Vui lòng kiểm tra lại."
        exit 1
    fi
        echo "Ansible đã được cài đặt thành công."
fi

echo "Đang chạy playbook..."
ansible-playbook -i inventory.ini playbook.yml

if [ $? -eq 0 ]; then
    echo "Playbook đã chạy thành công!"
else
    echo "Có lỗi xảy ra khi chạy playbook."
    exit 1
fi