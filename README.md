# Tensorflow-Lambda-Layer
Lets you import Tensorflow + Keras from an AWS lambda

## What is this?
It's a lambda layer that includes Tensorflow, Keras, and Numpy. You can use it to deploy serverless machine learning models.

## How do I use it?
### Easy way
You can use the ARN I've published: `arn:aws:lambda:us-east-1:347034527139:layer:Tensorflow:3`

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

## Caveats
This was stripped down to below the limit by setting up an environment with file access logging, running tensorflow, and 
removing any file that wasn't touched. If there's some conditional branch that I didn't manage to go down, it might fail --
test your app to see if everything works!

The unzipped file size is about 230 MB. The zipped size is about 60 MB, which is over the stated limit, but under the enforced limit.

I'll publish an ARN here as soon as I figure out how to make it shareable, which currently doesn't work from aws-cli.
