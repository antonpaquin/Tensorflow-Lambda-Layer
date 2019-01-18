# Tensorflow-Lambda-Layer
Lets you import Tensorflow + Keras from an AWS lambda

## What is this?
It's a lambda layer that includes Tensorflow, Keras, and Numpy. You can use it to deploy serverless machine learning models.

Serverless is especially nice for when you want to serve a model that will be accessed infrequently, without paying for an always-on ec2 instance. 

If you're a single developer or small org and all you want to do is [show off your binary classifier](http://isitanime.website), it's usually possible to stay within the free tier limits if you set things up right. 

And even if you're larger, serverless brings a lot of benefits, like transparent scaling and the ability to mostly ignore the hardware.

The problem is, some packages (like Tensorflow) end up hard to use. This repo is an attempt to alleviate that problem.

## How do I use it?
### Easy way
Pick an ARN for the version of Tensorflow you want from the table below (for example, `arn:aws:lambda:us-east-1:347034527139:layer:tf_1_8_keras:1`)

In the AWS lambda management console, create a new function you want to use Tensorflow in, or pick an existing function. 

Click
- layers
  - add layer
    - provide a layer version ARN
    
Paste the ARN in, add the layer, and you should be able to use the libraries as normal.

### Manual way
To manage the layer on your own, download latest release from [here](https://github.com/antonpaquin/Tensorflow-Lambda-Layer/releases)

From your AWS console, go to
- lambda management console
  - layers
    - create layer
    
Upload the zipfile, name the new layer whatever you like, and choose `Python 3.6` as the runtime.

Then, go to your function and select
- layers
  - add a layer
  
and select the newly created layer.

Once that's done, you should be able to `import tensorflow` in your function and use it as normal.

## ARN table

(Note: none of these are extensively tested)

### Tensorflow + Keras
tensorflow version | keras version | unzipped size | ARN
--- | --- | --- | ---
1.0.1 | 2.2.4 | 141M | arn:aws:lambda:us-east-1:347034527139:layer:tf_1_0_keras:1
1.1.0 | 2.2.4 | 146M | arn:aws:lambda:us-east-1:347034527139:layer:tf_1_1_keras:1
1.2.1 | 2.2.4 | 150M | arn:aws:lambda:us-east-1:347034527139:layer:tf_1_2_keras:1
1.3.0 | 2.2.4 | 155M | arn:aws:lambda:us-east-1:347034527139:layer:tf_1_3_keras:1
1.4.1 | 2.2.4 | 171M | arn:aws:lambda:us-east-1:347034527139:layer:tf_1_4_keras:1
1.5.1 | 2.2.4 | 185M | arn:aws:lambda:us-east-1:347034527139:layer:tf_1_5_keras:1
1.6.0 | 2.2.4 | 187M | arn:aws:lambda:us-east-1:347034527139:layer:tf_1_6_keras:1
1.7.1 | 2.2.4 | 191M | arn:aws:lambda:us-east-1:347034527139:layer:tf_1_7_keras:1
1.8.0 | 2.2.4 | 196M | arn:aws:lambda:us-east-1:347034527139:layer:tf_1_8_keras:1
1.9.0 | 2.2.4 | 200M | arn:aws:lambda:us-east-1:347034527139:layer:tf_1_9_keras:1
1.10.1 | 2.2.4 | 236M | arn:aws:lambda:us-east-1:347034527139:layer:tf_1_10_keras:1
1.11.0 | 2.2.4 | 204M | arn:aws:lambda:us-east-1:347034527139:layer:tf_1_11_keras:1
1.12.0 | 2.2.4 | 255M | arn:aws:lambda:us-east-1:347034527139:layer:tf_1_12_keras:1

### Tensorflow + Keras + Pillow
tensorflow version | keras version | PIL version | unzipped size | ARN
--- | --- | --- | --- | ---
1.8.0 | 2.2.4 | 5.4.1 | 203M | arn:aws:lambda:us-east-1:347034527139:layer:tf_keras_pillow:3

Size measurements taken with `du -sh`. Given that 1.12.0 is over 250MB, I'm not sure it's useable, but Amazon lets me upload it, so it's available.

## Build it yourself
The code involved in generating these layers is all included in `src` and `build_targets`. 
The code is a collection of shell scripts that constructs, uploads, and publishes the lambda zipfiles. It reads AWS credentials from $HOME/.aws, and spawns an instance to actually run the build process (note: does not shut it off automatically).

If you have a set of dependencies you'd like built into a layer, you should add a new directory, following this structure:

- `requirements.txt`: The pip packages to install
- `description.txt`: The description that will be attached to the published layer
- `hook.sh`: Extra commands that run as the last phase of the build step
- `test.py`: A python file that should trigger an access of every file used by the library in the course of its execution

If you send this in a pull request and it seems like something people will use, I'll run the build the next chance I get and add it here.

Or you can run it yourself with `aws-build-lambda.sh`. Make sure you know what this script is doing before you run it!

## I think you should build a layer with <packages x,y,z>
Let me know! It's fairly low cost to add a new layer. It doesn't even need to involve tensorflow.

## Caveats
This repo will minimize a deployment package by:

- Only copying source files and files accessed when `test.py` is run
- Stripping symbols from shared objects

These steps usually produce good results, but they may end up leaving out something essential. If you see an error that you're not expecting, file an issue including the error and the code that generates it, and I'll see what I can fix.
