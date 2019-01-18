#! /bin/bash

patch build/tensorflow/python/util/all_util.py < tf.diff
rm build/simple_model.h5
