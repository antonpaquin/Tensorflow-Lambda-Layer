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


def lambda_latest_version(name, region):
    lmbda = boto3.client('lambda', region_name=region)
    resp = lmbda.list_layer_versions(LayerName=name)
    return sorted(resp['LayerVersions'], key=lambda x: x['Version'])[-1]


def write_table(table_src, data):
    header = data[0].split(',')
    out_f = open(os.path.join(project_root, 'arn_tables', table_src + '.md'), 'w')
    out_f.write('# ' + table_src + '\n\n')
    for region in target_regions:
        out_f.write('### ' + region + '\n')
        out_f.write(' | '.join(header))
        out_f.write('\n')
        out_f.write(' | '.join(['---' for _ in header]))
        out_f.write('\n')
        for row in data[1:]:
            try:
                fields = row.split(',')
                build_target = fields[0]
                lambda_version = lambda_latest_version(fmt_build_name(build_target), region)
                context = {
                    'arn': lambda_version['LayerVersionArn'],
                }
                fmt_fields = [field.format(**context) for field in fields]
                out_f.write(' | '.join(fmt_fields))
                out_f.write('\n')
            except Exception:
                print(row)
                pass
        out_f.write('\n\n')
    out_f.close()


def main():
    table_dir = os.path.join(project_root, 'src', 'publish', 'tables')
    table_srcs = os.listdir(table_dir)
    
    for table_src in table_srcs:
        table_fname = os.path.join(table_dir, table_src)
        with open(table_fname, 'r') as in_f:
            data = in_f.read().split('\n')
        write_table(table_src, data)


if __name__ == '__main__':
    main()
