---
templating: mustache
---

# SageMaker Endpoint Operator Guide

## Endpoint Information

- **Endpoint Name:** `{{artifacts.endpoint.endpoint_name}}`
- **Instance Type:** `{{params.instance_type}}`
- **Instance Count:** `{{params.initial_instance_count}}`

---

## Testing the Endpoint

### Using Python (boto3)

```python
import boto3
import json

# Create SageMaker runtime client
runtime = boto3.client('sagemaker-runtime', region_name='{{artifacts.endpoint.region}}')

# Iris dataset features: [sepal_length, sepal_width, petal_length, petal_width]
# Class 0 = setosa, Class 1 = versicolor, Class 2 = virginica
test_data = {
    "instances": [
        [5.1, 3.5, 1.4, 0.2],  # Should predict class 0 (setosa)
        [6.2, 2.9, 4.3, 1.3],  # Should predict class 1 (versicolor)
        [7.7, 3.0, 6.1, 2.3]   # Should predict class 2 (virginica)
    ]
}

# Invoke the endpoint
response = runtime.invoke_endpoint(
    EndpointName='{{artifacts.endpoint.endpoint_name}}',
    ContentType='application/json',
    Accept='application/json',
    Body=json.dumps(test_data)
)

# Parse the response
result = json.loads(response['Body'].read().decode())
print("Predictions:", result['predictions'])
print("Probabilities:", result['probabilities'])

# Expected output:
# Predictions: [0, 1, 2]
# Probabilities: [[0.99, 0.01, 0.00], [0.02, 0.95, 0.03], [0.00, 0.05, 0.95]]
```

### Using AWS CLI

```bash
# Test the endpoint with a simple prediction
aws sagemaker-runtime invoke-endpoint \
    --endpoint-name {{artifacts.endpoint.endpoint_name}} \
    --content-type application/json \
    --accept application/json \
    --body '{"instances": [[5.1, 3.5, 1.4, 0.2]]}' \
    --region {{artifacts.endpoint.region}} \
    --cli-binary-format raw-in-base64-out \
    output.json

cat output.json
```

### Using curl (via Lambda or API Gateway)

If you've set up an API Gateway, you can test with curl:

```bash
curl -X POST https://your-api-gateway-url/predict \
    -H "Content-Type: application/json" \
    -d '{"instances": [[5.1, 3.5, 1.4, 0.2]]}'
```

---

## Understanding the POC Model

The deployed model is a **Random Forest Classifier** trained on the classic **Iris dataset**:

| Feature | Description | Range |
|---------|-------------|-------|
| Sepal Length | Length of sepal in cm | 4.3 - 7.9 |
| Sepal Width | Width of sepal in cm | 2.0 - 4.4 |
| Petal Length | Length of petal in cm | 1.0 - 6.9 |
| Petal Width | Width of petal in cm | 0.1 - 2.5 |

| Class | Flower Species |
|-------|---------------|
| 0 | Iris Setosa |
| 1 | Iris Versicolor |
| 2 | Iris Virginica |

---

## Monitoring

### Check Endpoint Status

```bash
aws sagemaker describe-endpoint \
    --endpoint-name {{artifacts.endpoint.endpoint_name}} \
    --region {{artifacts.endpoint.region}}
```

### View Invocation Metrics

CloudWatch metrics available:
- `Invocations` - Total number of requests
- `Invocation4XXErrors` - Client errors
- `Invocation5XXErrors` - Server errors
- `ModelLatency` - Time for model inference
- `OverheadLatency` - Time for SageMaker overhead

```bash
# Get invocation count for last hour
aws cloudwatch get-metric-statistics \
    --namespace AWS/SageMaker \
    --metric-name Invocations \
    --dimensions Name=EndpointName,Value={{artifacts.endpoint.endpoint_name}} Name=VariantName,Value=primary \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
    --period 300 \
    --statistics Sum \
    --region {{artifacts.endpoint.region}}
```

### View Logs

```bash
# Endpoint logs
aws logs tail /aws/sagemaker/Endpoints/{{artifacts.endpoint.endpoint_name}} --follow

# Training job logs (if you trained a custom model)
aws logs tail /aws/sagemaker/TrainingJobs --follow
```

---

## Updating the Model

To deploy a new model version:

1. Train a new model in SageMaker Studio
2. Upload the model artifact to S3
3. Update the `custom_model_s3_uri` parameter
4. Redeploy the bundle

Or use SageMaker's blue-green deployment:

```python
import boto3

sm = boto3.client('sagemaker')

# Create new endpoint config with new model
sm.create_endpoint_config(
    EndpointConfigName='{{artifacts.endpoint.endpoint_name}}-v2',
    ProductionVariants=[{
        'VariantName': 'primary',
        'ModelName': 'your-new-model',
        'InstanceType': '{{params.instance_type}}',
        'InitialInstanceCount': {{params.initial_instance_count}}
    }]
)

# Update endpoint to use new config
sm.update_endpoint(
    EndpointName='{{artifacts.endpoint.endpoint_name}}',
    EndpointConfigName='{{artifacts.endpoint.endpoint_name}}-v2'
)
```

---

## Scaling

### Manual Scaling

Update the `initial_instance_count` parameter and redeploy.

### Auto Scaling (via AWS Console or CLI)

```bash
# Register scalable target
aws application-autoscaling register-scalable-target \
    --service-namespace sagemaker \
    --resource-id endpoint/{{artifacts.endpoint.endpoint_name}}/variant/primary \
    --scalable-dimension sagemaker:variant:DesiredInstanceCount \
    --min-capacity 1 \
    --max-capacity 10 \
    --region {{artifacts.endpoint.region}}

# Create scaling policy
aws application-autoscaling put-scaling-policy \
    --service-namespace sagemaker \
    --resource-id endpoint/{{artifacts.endpoint.endpoint_name}}/variant/primary \
    --scalable-dimension sagemaker:variant:DesiredInstanceCount \
    --policy-name {{artifacts.endpoint.endpoint_name}}-scaling-policy \
    --policy-type TargetTrackingScaling \
    --target-tracking-scaling-policy-configuration '{
        "TargetValue": 70.0,
        "PredefinedMetricSpecification": {
            "PredefinedMetricType": "SageMakerVariantInvocationsPerInstance"
        },
        "ScaleInCooldown": 300,
        "ScaleOutCooldown": 60
    }' \
    --region {{artifacts.endpoint.region}}
```

---

## Troubleshooting

### Endpoint Stuck in "Creating"

1. Check CloudWatch logs for errors
2. Verify model artifact exists in S3
3. Ensure VPC has outbound internet access (for container image pull)

### Invocation Errors

1. Check request format matches expected input
2. Verify IAM permissions for invoking endpoint
3. Review model logs for inference errors

### High Latency

1. Consider larger instance type
2. Add more instances for traffic distribution
3. Optimize model for inference (quantization, etc.)
