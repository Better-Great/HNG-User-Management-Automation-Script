#!/bin/bash

# Script: create_users.sh
# Description: Creates users and groups based on input file
# Usage: ./create_users.sh INPUT_FILE

# Check if an input file was provided
if [ $# -ne 1 ]; then
    echo "Error: Please provide an input file."
    echo "Usage: $0 INPUT_FILE"
    exit 1
fi

# Check if the input file exists
if [ ! -f "$1" ]; then
    echo "Error: Input file '$1' does not exist."
    exit 1
fi

INPUT_FILE="$1"
LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.csv"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$(dirname "$PASSWORD_FILE")"

# Ensure the secure directory exists and set permissions
mkdir -p /var/secure
chmod 700 /var/secure

# Function to generate random password
generate_password() {
    openssl rand -base64 12
}

# Function to log messages
log_message() {
    echo "$(date): $1" >> "$LOG_FILE"
}

# Function to create user and groups
create_user() {
    local username=$1
    local groups=$2

    # Create user if it doesn't exist
    if ! id "$username" &>/dev/null; then
        password=$(generate_password)
        if useradd -m -s /bin/bash "$username"; then
            echo "$username:$password" | chpasswd
            echo "$username,$password" >> "$PASSWORD_FILE"
            log_message "User $username created"
            
            # Set up home directory permissions
            chown "$username:$username" "/home/$username"
            chmod 700 "/home/$username"
        else
            log_message "Failed to create user $username"
            return
        fi
    else
        log_message "User $username already exists"
    fi

    # Create personal group for user
    if ! getent group "$username" &>/dev/null; then
        if groupadd "$username"; then
            usermod -g "$username" "$username"
            log_message "Personal group $username created"
        else
            log_message "Failed to create personal group $username"
        fi
    fi

    # Add user to additional groups
    IFS=',' read -ra group_array <<< "$groups"
    for group in "${group_array[@]}"; do
        if ! getent group "$group" &>/dev/null; then
            if groupadd "$group"; then
                log_message "Group $group created"
            else
                log_message "Failed to create group $group"
                continue
            fi
        fi
        if usermod -a -G "$group" "$username"; then
            log_message "User $username added to group $group"
        else
            log_message "Failed to add user $username to group $group"
        fi
    done
}

# Read the input file and create users
while IFS=';' read -r username groups || [ -n "$username" ]; do
    # Remove any whitespace
    username=$(echo "$username" | tr -d '[:space:]')
    groups=$(echo "$groups" | tr -d '[:space:]')

    # Skip empty lines
    [ -z "$username" ] && continue

    create_user "$username" "$groups"
done < "$INPUT_FILE"

log_message "User creation process completed."
echo "User creation process completed. Check $LOG_FILE and $PASSWORD_FILE for details."