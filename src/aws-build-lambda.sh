ROOT_DIR="/home/anton/Programming/TensorflowLambdaLayer"
SSH_KEY="/home/anton/.ssh/Nimitz-120518.pem"
SSH_KEY_NAME="Nimitz-12.05.18"

# Test for the shell dependencies of this script: "aws" and "jq"
if command -v aws > /dev/null 2>&1; then
	echo "aws found"
else
	echo "This script requires the \"aws\" command line utility"
	exit 1
fi
if command -v jq > /dev/null 2>&1; then
	echo "jq found"
else
	echo "This script requires the \"jq\" command line utility"
	exit 1
fi

# We need a security group to allow global SSH. If it doesn't exist already,
# create it
if aws ec2 describe-security-groups --group-names "GlobalSSH" > /dev/null; then
	echo "Security group already exists"
else
	aws ec2 create-security-group \
		--group-name "GlobalSSH" \
		--description "Allow 22 traffic in"
	
	aws ec2 authorize-security-group-ingress \
		--group-name "GlobalSSH" \
		--protocol "tcp" \
		--port 22 \
		--cidr "0.0.0.0/0"
fi

# Create the dev instance to build the python deploy zip
# A t3.medium seems to work out fine
INSTANCE_ID=$(\
aws ec2 run-instances \
	--image-id "ami-4fffc834" \
	--key-name "$SSH_KEY_NAME" \
	--security-groups "GlobalSSH" \
	--instance-type "t3.medium" \
	--placement "AvailabilityZone=us-east-1b" \
	--count 1 \
	--block-device-mappings 'DeviceName=/dev/sda1,Ebs={VolumeSize=100,VolumeType=gp2}' \
| jq -r .Instances[0].InstanceId \
)
echo "Spawned instance: $INSTANCE_ID"

# Build a zipfile of all the files we need to send to the instance
# First step: if one already exists, remove it
if [ -f "$ROOT_DIR/build/transfer.zip" ]; then
	rm "$ROOT_DIR/build/transfer.zip"
fi

# Zip the source directory
pushd "$ROOT_DIR/build_targets"
zip -r build_targets.zip *
mv build_targets.zip "$ROOT_DIR/build/build_targets.zip"
popd

ls -1 "$ROOT_DIR/build_targets" > "$ROOT_DIR/build/build_targets.list"

# Add all files that we need to build to the zipfile
zip \
	-r "$ROOT_DIR/build/transfer.zip" \
	--junk-paths \
	"$ROOT_DIR/build/build_targets.zip" \
	"$ROOT_DIR/src/setup-server.sh" \
	"$ROOT_DIR/src/build-layer.sh" \
	"$ROOT_DIR/src/run-all.sh" \
	"$ROOT_DIR/build/build_targets.list"

# Also add aws credentials so that we can cli it to an s3 bucket
pushd "$HOME"
zip \
	-r "$ROOT_DIR/build/transfer.zip" \
	-g \
	".aws/" 
popd

# Wait for the instance to start -- it takes a while to boot up
echo "Waiting for instance to start..."
aws ec2 wait instance-running \
	--instance-ids "$INSTANCE_ID"
echo "Started"

# Get the public IP of the instance so we can SSH to it
echo "Fetching public ip..."
INSTANCE_IP=$(\
aws ec2 describe-instances \
	--instance-id "$INSTANCE_ID" \
	--query "Reservations[].Instances[].PublicIpAddress" \
	--output=text
)
echo "Found ip: $INSTANCE_IP"

# Write a helpful SSH host file pointing to the instance
cat > ssh_aws <<EOF
host awsec2
	HostName $INSTANCE_IP
	port 22
	User ec2-user
	IdentityFile $SSH_KEY
EOF

# Continuously try to SSH into the instance and do nothing
# We move on when it works
while ! ssh -i "$SSH_KEY" -oStrictHostKeyChecking=no ec2-user@$INSTANCE_IP true; do
	echo "SSH failed, retrying..."
	sleep 1
done

# Send over the transfer zip
scp \
	-i "$SSH_KEY" \
	"$ROOT_DIR/build/transfer.zip" \
	ec2-user@$INSTANCE_IP:~/transfer.zip

# Primary SSH -- all this runs on the server
ssh -i "$SSH_KEY" ec2-user@$INSTANCE_IP <<ENDSSH
	unzip transfer.zip
	rm transfer.zip
	./run-all.sh
ENDSSH
