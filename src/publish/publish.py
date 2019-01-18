#! /usr/bin/env python

import os

import boto3

from util import (
    project_root,
    release_target,
    aws_bucket,
    target_regions,
    s3_list_all,
    fmt_build_name,
)


def get_description(name):
    with open(os.path.join(project_root, 'build_targets', name, 'description.txt'), 'r') as in_f:
        res = in_f.read()
    return res.strip()


def get_release_layers():
    release_items = s3_list_all(aws_bucket + target_regions[0], 'layers/{}/'.format(release_target))   
    for item in release_items:
        if item['Key'].endswith('layer.zip'):
            build_target = item['Key'].split('/')[2]
            yield {
                'key': item['Key'],
                'lambda_name': fmt_build_name(build_target),
                'description': get_description(build_target),
                'build_target': build_target,
            }


def publish_layer(layer_spec):
    global arn_tables
    for region in target_regions:
        lmbda = boto3.client('lambda', region_name=region)
        resp = lmbda.publish_layer_version(
            LayerName=layer_spec['lambda_name'],
            Description=layer_spec['description'],
            Content={
                'S3Bucket': aws_bucket + region,
                'S3Key': layer_spec['key'],
            },
            CompatibleRuntimes=[
                'python3.6',
            ],
            LicenseInfo='MIT',
        )
        layer_arn = resp['LayerVersionArn']
        layer_version = resp['Version']
        lmbda.add_layer_version_permission(
            LayerName=layer_spec['lambda_name'],
            VersionNumber=layer_version,
            StatementId='publish',
            Action='lambda:GetLayerVersion',
            Principal='*',
        )
        print('Published {} in region {}'.format(layer_spec['lambda_name'], region))


def main():
    for layer_spec in get_release_layers():
        try:
            publish_layer(layer_spec)
        except Exception as err:
            print('Could not publish {}'.format(layer_spec['lambda_name']))
            print(err)


if __name__ == '__main__':
    main()
