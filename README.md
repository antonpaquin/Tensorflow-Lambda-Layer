# Tensorflow-Lambda-Layer
Lets you import Tensorflow + Keras from an AWS lambda

## What is this?
It's a lambda layer that includes Tensorflow, Keras, and Numpy. You can use it to deploy serverless machine learning models.

## How do I use it?
First, download latest release from [here](https://github.com/antonpaquin/Tensorflow-Lambda-Layer/releases)

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

## Caveats
This was stripped down to below the limit by setting up an environment with file access logging, running tensorflow, and 
removing any file that wasn't touched. If there's some conditional branch that I didn't manage to go down, it might fail --
test your app to see if everything works!

The unzipped file size is about 230 MB. The zipped size is about 60 MB, which is over the stated limit, but under the enforced limit.

I'll publish an ARN here as soon as I figure out how to make it shareable, which currently doesn't work from aws-cli.
