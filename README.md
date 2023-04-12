# Setup

### Create a virtualenv and install awscli-local and terraform-local
```shell
virtualenv -p python3 venv && . venv/bin/activate && pip install awscli-local terraform-local
```

### Setup an AWS profile called localstack
```shell
bin/setup-localstack-profile
```

### Create a file called `lambda.env` containing your LocalStack API key (LOCALSTACK_API_KEY).
* Note:  The following command will only work if you have the `LOCALSTACK_API_KEY` environment variable set.
```shell
echo "LOCALSTACK_API_KEY=${LOCALSTACK_API_KEY}" > lambda.env
```

# Run the lambda locally

### Bring up localstack
```shell
bin/up
```

### Build and deploy the lambda
```shell
if [ -z "${VIRTUAL_ENV}" ]; then . venv/bin/activate; fi
bin/deploy
```

### Run the lambda via the api gateway
```shell
if [ -z "${VIRTUAL_ENV}" ]; then . venv/bin/activate; fi
bin/invoke-worker
```

### Check the logs of the authorizer lambda docker container.  Note there is a SIGSEGV error for the X-Ray daemon.
```shell
docker logs $(docker ps -a | grep authorizer-handler | cut -d ' ' -f1)   
```

### Bring down localstack and cleanup
```shell
bin/down
```

# Other useful commands

### Run the lambda, show result, and show logs
```shell
if [ -z "${VIRTUAL_ENV}" ]; then . venv/bin/activate; fi
awslocal lambda invoke --function-name worker-local-worker-handler worker-local-worker-handler.log --payload 'eyJoZWxsbyI6IndvcmxkIn0='
cat worker-local-worker-handler.log; echo
awslocal logs tail /aws/lambda/worker-local-worker-handler
```

### Show aws log groups
```shell
if [ -z "${VIRTUAL_ENV}" ]; then . venv/bin/activate; fi
awslocal logs describe-log-groups | jq -r '.logGroups[].logGroupName'
```

### Check for LocalStack PRO activation
```shell
curl -s localhost:4566/_localstack/health\
 | jq .services.xray\
 | grep -q '"available"' && echo "LocalStack PRO activated" || echo "LocalStack PRO not activated"
```
