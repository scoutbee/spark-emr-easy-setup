#!/bin/bash
PASSWORD="password"
YUM_PACKAGES="libicu-devel"
PYTHON_PACKAGES="yarl multidict"

CORES=20
BID_PRICE=0.2
INSTANCE=r4.2xlarge

AWS_BUCKET_NAME="kyivpy25"
AWS_SUBNET_ID="subnet-072b3b0f1841cb799"
AWS_EMR_VERSION="5.21.0"
AWS_REGION="eu-west-1"
AWS_KEY_NAME="easy_spark_emr"

# env MUST have valid variables
# AWS_SECRET_ACCESS_KEY
# AWS_ACCESS_KEY_ID

aws emr create-cluster --release-label "emr-$AWS_EMR_VERSION" \
  --name "easy_spark_emr-$AWS_EMR_VERSION" \
  --tags Name="easy_spark_emr-$AWS_EMR_VERSION" \
  --applications Name=Hadoop Name=Hive Name=Spark Name=Pig Name=Tez Name=Ganglia Name=Presto \
  --ec2-attributes KeyName="$AWS_KEY_NAME",InstanceProfile=EMR_EC2_DefaultRole,SubnetId="$AWS_SUBNET_ID" \
  --configurations "file://config.json" \
  --service-role EMR_DefaultRole \
  --instance-fleets \
    InstanceFleetType=MASTER,TargetOnDemandCapacity=1,InstanceTypeConfigs=['{InstanceType='"$INSTANCE"'}'] \
    InstanceFleetType=CORE,TargetSpotCapacity="$CORES",InstanceTypeConfigs=['{InstanceType='"$INSTANCE"',BidPrice='"$BID_PRICE"'}'] \
  --region "$AWS_REGION" \
  --log-uri "s3://$AWS_BUCKET_NAME/easy_spark_emr/logs/"`date +%Y-%m-%d_%H:%M:%S` \
  --bootstrap-actions \
    Name='jupyter',Path="s3://$AWS_BUCKET_NAME/easy_spark_emr/setup/bootstrap.sh",Args=[--password,"$PASSWORD",--notebook-dir,"s3://$AWS_BUCKET_NAME/easy_spark_emr/notebooks/",--python-packages,"$PYTHON_PACKAGES",--yum-packages,"$YUM_PACKAGES",--aws-bucket-name,"$AWS_BUCKET_NAME",--aws-region,"$AWS_REGION"]
