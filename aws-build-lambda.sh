ROOT_DIR="/home/anton/Programming/TensorflowLambdaLayer"
SSH_KEY="/home/anton/.ssh/Nimitz-120518.pem"
SSH_KEY_NAME="Nimitz-12.05.18"
LAMBDA_S3_BUCKET="antonpaquin-lambda-zip"

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
# A t2.small seems to work out fine
INSTANCE_ID=$(\
aws ec2 run-instances \
	--image-id "ami-4fffc834" \
	--key-name "$SSH_KEY_NAME" \
	--security-groups "GlobalSSH" \
	--instance-type "t3.medium" \
	--placement "AvailabilityZone=us-east-1b" \
	--count 1 \
| jq -r .Instances[0].InstanceId \
)
echo "Spawned instance: $INSTANCE_ID"

# Zip the source directory
# Source files for the target model
pushd "$ROOT_DIR/src"
zip -r src.zip *
mv src.zip "$ROOT_DIR/objs/src.zip"
popd

# Build a zipfile of all the files we need to send to the instance
# First step: if one already exists, remove it
if [ -f "$ROOT_DIR/objs/transfer.zip" ]; then
	rm "$ROOT_DIR/objs/transfer.zip"
fi

# Add all files that we need to build to the zipfile
zip \
	-r "$ROOT_DIR/objs/transfer.zip" \
	--junk-paths \
	"$ROOT_DIR/objs/src.zip" \
	"$ROOT_DIR/objs/tf.diff"

# Also add aws credentials so that we can cli it to an s3 bucket
pushd "$HOME"
zip \
	-r "$ROOT_DIR/objs/transfer.zip" \
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
	"$ROOT_DIR/objs/transfer.zip" \
	ec2-user@$INSTANCE_IP:~/transfer.zip

# Primary SSH -- all this runs on the server
ssh -i "$SSH_KEY" ec2-user@$INSTANCE_IP <<ENDSSH
	# Unzip the transfer file sent to the server
	unzip transfer.zip
	rm transfer.zip

	# Install some libraries needed to build openssl and python
	sudo yum groupinstall -y \
		development

	sudo yum install -y \
		zlib-devel \
		openssl-devel 
	
	# Install openssl from source
	wget https://github.com/openssl/openssl/archive/OpenSSL_1_0_2l.tar.gz
	tar -zxvf OpenSSL_1_0_2l.tar.gz
	pushd openssl-OpenSSL_1_0_2l/
	./config shared
	make
	sudo make install
	export LD_LIBRARY_PATH=/usr/local/ssl/lib/
	popd
	rm -rf OpenSSL_1_0_2l.tar.gz openssl-OpenSSL_1_0_2l/
	
	# Install python from source
	wget https://www.python.org/ftp/python/3.6.6/Python-3.6.6.tar.xz
	tar xJf Python-3.6.6.tar.xz
	pushd Python-3.6.6
	./configure
	make
	sudo make install
	popd
	sudo rm -rf Python-3.6.6.tar.xz Python-3.6.6

	# Start up the installation virtualenv
	sudo env PATH=\$PATH pip3 install --upgrade virtualenv
	virtualenv -p python3 env
	source env/bin/activate
	
	# Pip install necessary python libraries
	pip3 install \
		tensorflow==1.8.0 \
        keras
	
	# Add the "epel" yum repo and install inotifytools
	wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
	sudo yum install -y \
		epel-release-latest-7.noarch.rpm
	rm epel-release-latest-7.noarch.rpm
	sudo yum install -y \
		inotify-tools

	# Unzip the src and put it in the "build" directory
	mkdir build
	mv src.zip build
	pushd build
	unzip src.zip
	rm src.zip
	popd
	
	# We want to find out what files python actually uses in the process of running our script
	# So we'll set up a listener for all accessed files in the virtualenv
	inotifywait \
		-m \
		-e access \
		-o inotifywait.list \
		--format "%w%f" \
		-r \
		\$VIRTUAL_ENV/lib/python3.6/site-packages/ &
	
	# Make sure to save the PID so it can be killed later
	INOTIFY="\$!"
	
	# Sleep to give inotify time to set up the watches
	sleep 1;
	
	# Now we run the classification on two images
	# This will cause python to do its thing with inotify watching,
	# and we'll have a list of files that python needs to run a classification
	pushd build
	python3 test.py
	kill \$INOTIFY
	popd
	
	# Copy over all of the used files to the build directory
	pushd build
	for f in \$(cat /home/ec2-user/inotifywait.list); do
		if [ -f \$f ]; then
			REL=\$(dirname \$f | cut -c 48-)
			mkdir -p \$REL
			cp \$f \$REL
		fi
	done
	
	# Copy all the python files, because they're small and tend to break
	# things if they're absent
	pushd \$VIRTUAL_ENV/lib/python3.6/site-packages/
	find . -name "*.py" | cut -c 3- > \$HOME/pydep.list
	popd

	for f in \$(cat \$HOME/pydep.list); do
		cp "\$VIRTUAL_ENV/lib/python3.6/site-packages/\$f" "/home/ec2-user/build/\$f" 2>/dev/null
	done
	popd

	# Tensorflow by default has an error when we just run this process, so patch that out
	patch build/tensorflow/python/util/all_util.py < tf.diff
	
	# And start the final zipping process
	pushd build

	# Strip unnecessary symbols from binaries (shrinks about 90 MB)
	find . -name "*.so" | xargs strip

	# Remove the leftover test image files
	rm test.py
	popd
	

	# Zip up the build for lambda
	mv build python
	zip -r9 lambda.zip python/
	mv lambda.zip ..
	popd

	# And copy it to an s3 bucket
	aws s3 cp lambda.zip s3://$LAMBDA_S3_BUCKET/tf_lambda_layer.zip
ENDSSH
