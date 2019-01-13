#! /bin/bash

patch build/tensorflow/python/util/all_util.py < tf.diff

cp $VIRTUAL_ENV/lib/python3.6/site-packages/PIL/_imaging.cpython-36m-x86_64-linux-gnu.so build/PIL/_imaging.cpython-36m-x86_64-linux-gnu.so
cp $VIRTUAL_ENV/lib/python3.6/site-packages/PIL/.libs/* build/PIL/.libs/
