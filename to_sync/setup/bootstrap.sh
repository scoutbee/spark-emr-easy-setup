set -eo pipefail

CONDA_VERSION=4.5.12

PYTHON_PACKAGES=""
YUM_PACKAGES=""

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    --password)
    JUPYTER_PASSWORD="$2"
    shift # past argument
    shift # past value
    ;;
    --aws-region)
    AWS_REGION="$2"
    shift # past argument
    shift # past value
    ;;
    --aws-bucket-name)
    AWS_BUCKET_NAME="$2"
    shift # past argument
    shift # past value
    ;;
    --python-packages)
    PYTHON_PACKAGES="$2"
    shift # past argument
    shift # past value
    ;;
    --yum-packages)
    YUM_PACKAGES="$2"
    shift # past argument
    shift # past value
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

# install git
sudo yum install -y git

if [ ! "$YUM_PACKAGES" = "" ]; then
  sudo yum install -y $YUM_PACKAGES
fi

sudo ldconfig

# Install conda
wget https://repo.continuum.io/miniconda/Miniconda3-"${CONDA_VERSION}"-Linux-x86_64.sh -O /home/hadoop/miniconda.sh\
    && /bin/bash ~/miniconda.sh -b -p /home/hadoop/conda
echo -e '\nexport PATH=/home/hadoop/conda/bin:$PATH' >> /home/hadoop/.bashrc && source /home/hadoop/.bashrc
conda config --set always_yes yes --set changeps1 no

# Install additional libraries for all instances with conda
conda install conda="${CONDA_VERSION}"

conda config -f --add channels conda-forge
conda config -f --add channels defaults

conda install "pyspark==2.4.0" boto3 botocore py4j fastparquet python-snappy "pyarrow<0.15.0" numpy pandas cython

pip install -U pip setuptools wheel

pip install h2o_pysparkling_2.4

if [ ! "$PYTHON_PACKAGES" = "" ]; then
  pip install $PYTHON_PACKAGES
fi

# cleanup
rm ~/miniconda.sh

echo bootstrap_conda.sh completed. PATH now: $PATH

# setup python 3.7 in the master and workers
export PYSPARK_PYTHON="/home/hadoop/conda/bin/python3.7"

# install dependencies for s3fs-fuse to access and store notebooks
sudo yum install -y libcurl cyrus-sasl readline readline-devel

sudo aws s3 cp "s3://$AWS_BUCKET_NAME/easy_spark_emr/setup/s3fs" /usr/local/bin/s3fs
sudo chmod +x /usr/local/bin/s3fs
sudo su -c 'echo user_allow_other >> /etc/fuse.conf'
mkdir -p "/mnt/s3fs-cache"
mkdir -p "/mnt/s3-bucket"
/usr/local/bin/s3fs -o allow_other -o iam_role=auto -o umask=0 -o url="https://s3-$AWS_REGION.amazonaws.com"  -o no_check_certificate -o enable_noobj_cache -o use_cache=/mnt/s3fs-cache $AWS_BUCKET_NAME /mnt/s3-bucket

# Install Jupyter Note book on master and libraries
conda install jupyter
# pin notebook
conda install notebook==5.7.8
# do not use asyncio loop
pip install "tornado<5"

# jupyter configs
mkdir -p ~/.jupyter
touch ~/.jupyter/jupyter_notebook_config.py
HASHED_PASSWORD=$(python -c "from notebook.auth import passwd; print(passwd('$JUPYTER_PASSWORD'))")
echo "c.NotebookApp.password = u'$HASHED_PASSWORD'" >> ~/.jupyter/jupyter_notebook_config.py
echo "c.NotebookApp.open_browser = False" >> ~/.jupyter/jupyter_notebook_config.py
echo "c.NotebookApp.ip = '*'" >> ~/.jupyter/jupyter_notebook_config.py
echo "c.NotebookApp.notebook_dir = '/mnt/s3-bucket/easy_spark_emr/notebooks'" >> ~/.jupyter/jupyter_notebook_config.py
echo "c.ContentsManager.checkpoints_kwargs = {'root_dir': '.checkpoints'}" >> ~/.jupyter/jupyter_notebook_config.py
echo 'c.NotebookApp.allow_remote_access = True' >> ~/.jupyter/jupyter_notebook_config.py

cd ~
sudo cat << EOF > /home/hadoop/jupyter.conf
description "jupyter"
author      "hellysmile"

start on runlevel [2345]
stop on runlevel [016]

respawn
respawn limit 0 10

chdir /mnt/s3-bucket/easy_spark_emr/notebooks

script
    sudo su - hadoop > /var/log/jupyter.log 2>&1 << BASH_SCRIPT
        export PYSPARK_DRIVER_PYTHON="/home/hadoop/conda/bin/jupyter"
        export PYSPARK_DRIVER_PYTHON_OPTS="notebook --log-level=INFO"
        export PYSPARK_PYTHON="/home/hadoop/conda/bin/python3.7"
        export JAVA_HOME="/etc/alternatives/jre"
        export SPARK_HOME="/usr/lib/spark"
        pyspark
   BASH_SCRIPT
end script
EOF
sudo mv /home/hadoop/jupyter.conf /etc/init/jupyter.conf
sudo chown root:root /etc/init/jupyter.conf

# be sure that jupyter daemon is registered in initctl
sudo initctl reload-configuration

wait_for_spark() {
  while [ ! -f /var/run/spark/spark-history-server.pid ]
  do
    sleep 1
    echo "waiting for spark..."
  done
}

start_jupyter() {
    wait_for_spark

    # start jupyter daemon
    sudo initctl start jupyter
}

start_jupyter&
