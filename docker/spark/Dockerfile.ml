FROM spark-custom:3.5.7

RUN pip3 install --no-cache-dir boto3 scikit-learn
