easy_spark_emr
==============

:info: easy spark setup on aws emr

Installation
------------

.. code-block:: shell

    git clone https://github.com/scoutbeedev/easy_spark_emr.git
    cd easy_spark_emr

    pip install awscli

    export AWS_SECRET_ACCESS_KEY=XXX
    export AWS_ACCESS_KEY_ID=XXX

    # create default EMR roles
    aws emr create-default-roles
    # create S3 bucket for jupyter notebooks
    aws --region=XXX s3 mb s3://XXX
    # create ssh key-pair
    aws --region=XXX ec2 create-key-pair --key-name easy_spark_emr

    # edit run_cluster for AWS_SUBNET_ID and AWS_BUCKET_NAME
    # AWS_SUBNET_ID can be found at
    # https://console.aws.amazon.com/vpc/home#subnets:sort=SubnetId
    ./run_cluster.sh

open `aws emr console <https://console.aws.amazon.com/elasticmapreduce/home>`_

go to Your region

find Your cluster by id

click on ElasticMapReduce-master security group

add `All traffic` rule for Your `IP`

go back to the cluster

open `http://Master public DNS:8888/`

see jupyter up and running ;)

Notes
-----

Do not forget to terminate Your cluster

