---
templating: mustache
---

# SageMaker Domain Operator Guide

## Domain Information

- **Domain ID:** `{{artifacts.domain.domain_id}}`
- **Studio URL:** [Open SageMaker Studio]({{artifacts.domain.studio_url}})
- **Execution Role:** `{{artifacts.domain.execution_role_arn}}`
- **Artifacts Bucket:** `{{artifacts.domain.default_bucket}}`

---

## Accessing SageMaker Studio

1. Open the [SageMaker Studio URL]({{artifacts.domain.studio_url}})
2. Select the `default-user` profile (or create your own)
3. Wait for the JupyterServer to start (first time takes 2-3 minutes)

---

## Quick Start: Training Your First Model

Once in Studio, create a new notebook and run:

```python
import sagemaker
from sagemaker import get_execution_role
from sagemaker.sklearn import SKLearn

# Get the execution role
role = get_execution_role()
print(f"Using role: {role}")

# Create a simple training script
training_script = """
import argparse
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
import joblib
import os

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--n-estimators', type=int, default=100)
    args = parser.parse_args()

    # Load sample data (iris dataset)
    from sklearn.datasets import load_iris
    iris = load_iris()
    X_train, X_test, y_train, y_test = train_test_split(
        iris.data, iris.target, test_size=0.2, random_state=42
    )

    # Train model
    model = RandomForestClassifier(n_estimators=args.n_estimators)
    model.fit(X_train, y_train)

    # Save model
    joblib.dump(model, os.path.join('/opt/ml/model', 'model.joblib'))
    print(f"Model accuracy: {model.score(X_test, y_test):.2f}")
"""

# Write the training script
import os
os.makedirs('src', exist_ok=True)
with open('src/train.py', 'w') as f:
    f.write(training_script)

# Configure and run training job
sklearn_estimator = SKLearn(
    entry_point='train.py',
    source_dir='src',
    role=role,
    instance_count=1,
    instance_type='ml.m5.large',
    framework_version='1.2-1',
    py_version='py3',
    hyperparameters={
        'n-estimators': 100
    }
)

# Start training
sklearn_estimator.fit()

# Get the model artifact location
model_data = sklearn_estimator.model_data
print(f"Model saved to: {model_data}")
```

---

## Using Pre-built Models (JumpStart)

SageMaker JumpStart provides pre-trained models:

```python
from sagemaker.jumpstart.model import JumpStartModel

# Deploy a pre-trained text classification model
model = JumpStartModel(model_id="huggingface-text2text-flan-t5-base")
predictor = model.deploy()

# Make predictions
response = predictor.predict("Translate to French: Hello, how are you?")
print(response)

# Clean up
predictor.delete_endpoint()
```

---

## S3 Bucket Structure

Your artifacts bucket `{{artifacts.domain.default_bucket}}` is organized as:

```
s3://{{artifacts.domain.default_bucket}}/
├── sharing/           # Shared notebook outputs
├── training-jobs/     # Training job outputs
├── models/           # Trained model artifacts
├── data/             # Training/inference data
└── pipelines/        # Pipeline artifacts
```

### Upload Data

```python
import sagemaker

session = sagemaker.Session()
bucket = '{{artifacts.domain.default_bucket}}'

# Upload local data
input_data = session.upload_data(
    path='./my-data.csv',
    bucket=bucket,
    key_prefix='data/my-dataset'
)
print(f"Data uploaded to: {input_data}")
```

---

## Monitoring & Costs

### Check Running Instances

```bash
aws sagemaker list-apps \
    --domain-id {{artifacts.domain.domain_id}} \
    --region {{artifacts.domain.region}}
```

### Stop Idle Apps (Save Costs)

```bash
# List and delete idle JupyterServer apps
aws sagemaker list-apps \
    --domain-id {{artifacts.domain.domain_id}} \
    --region {{artifacts.domain.region}} \
    --query "Apps[?Status=='InService']"
```

---

## Creating Additional User Profiles

For team members, create user profiles via Terraform or AWS CLI:

```bash
aws sagemaker create-user-profile \
    --domain-id {{artifacts.domain.domain_id}} \
    --user-profile-name "data-scientist-alice" \
    --region {{artifacts.domain.region}}
```

---

## Troubleshooting

### Studio Won't Start

1. Check subnet has outbound internet access (NAT Gateway required for private subnets)
2. Verify security group allows outbound HTTPS (443)
3. Check IAM role has `AmazonSageMakerFullAccess`

### Training Job Fails

1. Check CloudWatch logs: `/aws/sagemaker/TrainingJobs`
2. Verify S3 bucket permissions
3. Ensure training instance type is available in region
