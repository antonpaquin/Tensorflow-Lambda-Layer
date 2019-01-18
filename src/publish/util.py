#! /usr/bin/env python

import os


project_root = os.path.abspath(__file__)
for _ in range(3):
    project_root = os.path.dirname(project_root)

release_target = '2'
aws_bucket = 'antonpaquin-lambda-zip-'

target_regions = [
    'us-east-2',
    'us-east-1',
    'us-west-1',
    'us-west-2',
    'ap-south-1',
    'ap-northeast-2',
    'ap-southeast-1',
    'ap-southeast-2',
    'ap-northeast-1',
    'ca-central-1',
    'eu-central-1',
    'eu-west-1',
    'eu-west-2',
    'eu-west-3',
    'eu-north-1',
    'sa-east-1',
]

def s3_list_all(bucket, prefix):
    s3 = boto3.client('s3')
    request = {
        'Bucket': bucket,
        'Prefix': prefix,
    }
    has_more = True
    while has_more:
        response = s3.list_objects(**request)
        has_more = response['IsTruncated']
        if has_more:
            request['Marker'] = response['Contents'][-1]['Key']
        for item in response['Contents']:
            yield item


def fmt_build_name(name):
    allowed_chars = set([
        *map(chr, range(ord('a'),ord('z')+1)),
        *map(chr, range(ord('A'),ord('Z')+1)),
        *map(chr, range(ord('0'),ord('9')+1)),
    ])
    return ''.join([ch if ch in allowed_chars else '_' for ch in name])
