#! /bin/bash

LAMBDA_S3_BUCKET="antonpaquin-lambda-zip"
LAYER_NAME="$1"
LAYER_ROOT="/home/ec2-user/build/$LAYER_NAME"
LAYER_UPLOAD_NAME="$(echo "$LAYER_NAME" | sed s/'[^a-zA-Z0-9]/_/g')"

pushd $LAYER_NAME

virtualenv -p python3 env
source env/bin/activate

# Pip install necessary python libraries
pip3 install -r requirements.txt

# We want to find out what files python actually uses in the process of running our script
# So we'll set up a listener for all accessed files in the virtualenv
inotifywait \
	-m \
	-e access \
	-o inotifywait.list \
	--format "%w%f" \
	-r \
	$VIRTUAL_ENV/lib/python3.6/site-packages/ &

# Make sure to save the PID so it can be killed later
INOTIFY="$!"

# Sleep to give inotify time to set up the watches
sleep 1;

# Run a test, which should touch every file that the layer will need to run
mkdir build
cp test.py build
pushd build
python3 test.py
kill $INOTIFY
popd

# Copy over all of the used files to the build directory
pushd build
for f in $(cat $LAYER_ROOT/inotifywait.list); do
	if [ -f $f ]; then
		REL=$(dirname $f | sed 's/.*site-packages\///g')
		mkdir -p $REL
		cp $f $REL
	fi
done

# Copy all the python files, because they're small and tend to break
# things if they're absent
pushd $VIRTUAL_ENV/lib/python3.6/site-packages/
find . -name "*.py" | cut -c 3- > $LAYER_ROOT/pydep.list
popd

for f in $(cat $LAYER_ROOT/pydep.list); do
	cp "$VIRTUAL_ENV/lib/python3.6/site-packages/$f" "$LAYER_ROOT/build/$f" 2>/dev/null
done
popd

# And start the final zipping process
pushd build

# Strip unnecessary symbols from binaries
find . -name "*.so" | xargs strip

# Remove the leftover test script
rm test.py
popd

if [ -f hook.sh ]; then
    ./hook.sh
fi

# Zip up the build for lambda
mv build python
zip -r9 lambda.zip python/

# Freeze the env for later reference
pip freeze > pip.txt

# And copy it to an s3 bucket
aws s3 cp lambda.zip s3://$LAMBDA_S3_BUCKET/layers/$LAYER_NAME/layer.zip
aws s3 cp pip.txt s3://$LAMBDA_S3_BUCKET/layers/$LAYER_NAME/pip.txt
aws lambda publish-layer-version \
    --layer-name "$LAYER_UPLOAD_NAME" \
    --description "$(cat description.txt)" \
    --content S3Bucket=$LAMBDA_S3_BUCKET,S3Key=layers/$LAYER_NAME/layer.zip \
    --compatible-runtimes python3.6 \
    --license-info "MIT"
