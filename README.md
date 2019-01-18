# Tensorflow-Lambda-Layer
Lets you import Tensorflow + Keras from an AWS lambda

## What is this?
It's a lambda layer that includes Tensorflow, Keras, and Numpy. You can use it to deploy serverless machine learning models.

Serverless is especially nice for when you want to serve a model that will be accessed infrequently, without paying for an always-on ec2 instance. 

If you're a single developer or small org and all you want to do is [show off your binary classifier](http://isitanime.website), it's usually possible to stay within the free tier limits if you set things up right. 

And even if you're larger, serverless brings a lot of benefits, like transparent scaling and the ability to mostly ignore the hardware.

The problem is, some packages (like Tensorflow) end up hard to use. This repo is an attempt to alleviate that problem.

## How do I use it?
Pick an ARN from the tables for the region and Tensorflow version you want (for example, `arn:aws:lambda:us-west-2:347034527139:layer:tf_1_11_keras:1`)

Tables:
- [tensorflow and keras](https://github.com/antonpaquin/Tensorflow-Lambda-Layer/blob/master/arn_tables/tensorflow_keras.md)
- [tensorflow, keras, and PIL](https://github.com/antonpaquin/Tensorflow-Lambda-Layer/blob/master/arn_tables/tensorflow_keras_pillow.md)

In the AWS lambda management console, create a new function you want to use Tensorflow in, or pick an existing function. 

Click
- layers
  - add layer
    - provide a layer version ARN
    
Paste the ARN in, add the layer, and you should be able to use the libraries as normal.

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

Tensorflow 1.12 + Keras clocks in at 282M, which is too big to fit into a lambda layer. Unless I can find a way to further reduce the size, I can't support this combination.
