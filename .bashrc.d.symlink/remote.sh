###############################################################################
#
# Functions to ease dealing with remote machines

remote_install() {
    sshnohost $1 < $HOME/src/scripts/$2.sh
}

remote_setup() {
    remote_install $1 dotfiles
    remote_install $1 tmux
    remote_install $1 btop
    ssh_socks $1
}

ec2_instance_from_tag() {
    # Set variables for instance ID and public IP retrieved using tag name

    if [ $# -eq 0 ]; then
        echo "ERROR: You must provide an instance name"
        return 1
    fi
    ec2_instance_id=`aws ec2 describe-instances \
        --filters "Name=tag-value,Values=$1" \
        --query "Reservations[*].Instances[*].[InstanceId]" --output=text`

    ec2_instance_public_ip=`aws ec2 describe-instances \
        --instance-ids $ec2_instance_id \
        --query "Reservations[*].Instances[*].PublicIpAddress" --output=text`

    ec2_instance_private_ip=`aws ec2 describe-instances \
        --instance-ids $ec2_instance_id \
        --query "Reservations[*].Instances[*].PrivateIpAddress" --output=text`
}

stop_ec2() {
    if [ $# -eq 0 ]; then
        echo "ERROR: You must provide an instance name"
        return 1
    fi
    # Retrieve instance ID and public IP using tag name
    ec2_instance_from_tag $1
    # Stop instance
    aws ec2 stop-instances --instance-ids $ec2_instance_id
    # TODO: Remove Slack reminder
    #wget -q -O - "$SLACK_API_URL/users.info?token=$SLACK_TOKEN&user=U0763TLKD" >/dev/null 2>&1
}

start_ec2() {
    if [ $# -eq 0 ]; then
        echo "ERROR: You must provide an instance name"
        return 1
    fi
    # Retrieve instance ID and public IP using tag name
    ec2_instance_from_tag $1
    # Start instance
    aws ec2 start-instances --instance-ids $ec2_instance_id
    #slack_remind_me 'to stop the EC2 machine' 'today at 17:00'
}
