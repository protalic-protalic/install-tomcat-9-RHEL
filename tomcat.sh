#!/bin/bash

# Function to check if a service is running
check_service_status() {
    systemctl is-active --quiet "$1"
}

# Function to get the current Tomcat port
get_tomcat_port() {
    grep 'Connector port' /opt/tomcat/conf/server.xml | grep 'protocol="HTTP/1.1"' | grep -o 'port="[0-9]*"' | sed 's/port="\([0-9]*\)"/\1/'
}

# Function to get the public IP address
get_public_ip() {
    curl -s http://checkip.amazonaws.com
}

# Check if Java is installed
if ! java -version 2>&1 | grep -q "17.0.12"; then
    echo "This may take some time as necessary packages getting installed. Please wait..."
    if ! sudo yum install java-17-openjdk-devel -y &> /dev/null; then
        echo "sudo yum update -y &> /dev/null;sudo yum install wget -y &> /dev/null;sudo mkdir /opt/java-17 &> /dev/null;wget https://download.java.net/java/GA/jdk17/0d483333a00540d886896bac774ff48b/35/GPL/openjdk-17_linux-x64_bin.tar.gz &> /dev/null;sudo tar xf  openjdk-17_linux-x64_bin.tar.gz -C /opt/java-17/ --strip-components=1 &> /dev/null;export JAVA_HOME=/opt/java-17 &> /dev/null;export PATH=$JAVA_HOME/bin:$PATH  &> /dev/null; echo "Java JDK 17 installed. Here is the version details:"; java --version
    fi
else
    echo "Java 17 is already installed." &> /dev/null
fi

# Check if Tomcat is installed
if [ ! -d "/opt/tomcat" ]; then
    echo "Tomcat is not installed. Installing Tomcat..."

    sudo mkdir -p /opt/tomcat

    # Check if the tomcat user exists
    if id "tomcat" &>/dev/null; then
        echo "" &> /dev/null
    else
        sudo useradd -m -U -d /opt/tomcat -s /bin/false tomcat &> /dev/null
    fi

    sudo yum install wget -y &> /dev/null

    # Save the current directory
    original_dir=$(pwd)
    cd /tmp
    wget https://dlcdn.apache.org/tomcat/tomcat-9/v9.0.105/bin/apache-tomcat-9.0.105.tar.gz &> /dev/null
    sudo tar xf apache-tomcat-9.0.105.tar.gz -C /opt/tomcat --strip-components=1
    sudo chown -R tomcat: /opt/tomcat
    sudo chmod -R 755 /opt/tomcat

    # Prompt for port selection
    read -p "Enter port for Tomcat (8080 or 9050): " port
    if [[ "$port" != "8080" && "$port" != "9050" ]]; then
        echo "Invalid port. Defaulting to 8080."
        port=8080
    else
        echo "Updated the port for Tomcat to: $port"
    fi

    sudo sed -i "s/port=\"8080\"/port=\"$port\"/" /opt/tomcat/conf/server.xml

    # Add service configuration
    sudo cp "$original_dir/tomcat.service" /etc/systemd/system/tomcat.service
    sudo cp "$original_dir/tomcat-users.txt" /opt/tomcat/conf/tomcat-users.xml

    # Enable manager and host manager
    sudo mkdir -p /opt/tomcat/webapps/manager/META-INF
    sudo mkdir -p /opt/tomcat/webapps/host-manager/META-INF
    sudo cp "$original_dir/context.txt" /opt/tomcat/webapps/manager/META-INF/context.xml
    sudo cp "$original_dir/context.txt" /opt/tomcat/webapps/host-manager/META-INF/context.xml

    sudo systemctl daemon-reload
    sudo systemctl start tomcat
    sudo systemctl enable tomcat &> /dev/null
    echo ""
    echo "Tomcat installed! Also manager and Host manager activated!"
else
    port=$(get_tomcat_port)
    echo "Tomcat is already installed on port: $port"


    while true; do
        read -p "Do you want to change the port? (yes/no): " change_port
        if [[ "$change_port" == "yes" ]]; then
            read -p "Enter new port for Tomcat (8080 or 9050): " new_port
            if [[ "$new_port" != "8080" && "$new_port" != "9050" ]]; then
                echo "Invalid port. Keeping the current port: $port."
            else
                sudo sed -i "s/port=\"$port\"/port=\"$new_port\"/" /opt/tomcat/conf/server.xml
                sudo systemctl restart tomcat
                port=$new_port
                echo "Port changed to: $port and Tomcat restarted."
            fi
            break
        elif [[ "$change_port" == "no" ]]; then
            break
        else
            echo "Invalid response! Please enter 'yes' or 'no'."
        fi
    done

    
    # Save the current directory
    original_dir=$(pwd)

    # Add service configuration
    sudo cp "$original_dir/tomcat.service" /etc/systemd/system/tomcat.service
    sudo cp "$original_dir/tomcat-users.txt" /opt/tomcat/conf/tomcat-users.xml

    # Enable manager and host manager if not enabled
    sudo mkdir -p /opt/tomcat/webapps/manager/META-INF
    sudo mkdir -p /opt/tomcat/webapps/host-manager/META-INF
    sudo cp "$original_dir/context.txt" /opt/tomcat/webapps/manager/META-INF/context.xml
    sudo cp "$original_dir/context.txt" /opt/tomcat/webapps/host-manager/META-INF/context.xml
    sudo systemctl daemon-reload

    # Check if Tomcat is running
    if ! check_service_status tomcat; then
        echo "Tomcat is not running. Attempting to restart..."
        sudo systemctl restart tomcat
        if ! check_service_status tomcat; then
            echo "Failed to restart Tomcat. Please check the logs for more details."
            sudo journalctl -u tomcat --since "5 minutes ago"
            exit 1
        fi
    else
        echo "Tomcat is running."
    fi
fi

# Get the public IP address and display the URL to access Tomcat
public_ip=$(get_public_ip)
echo ""
echo ""
echo "##########################################################"
echo "# You can now access Tomcat at: http://$public_ip:$port  #"
echo "##########################################################"
echo ""
echo ""
echo "Login details for manager and host-manager by default is:"
echo "Usename: admin"
echo "Password: admin"
echo ""
