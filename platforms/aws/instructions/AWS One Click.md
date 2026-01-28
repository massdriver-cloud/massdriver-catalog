# Importing your AWS role for Massdriver to assume

## How Massdriver uses your role

To keep your environment secure, Massdriver uses a role with a trust policy to access your AWS account for provisioning and monitoring of your infrastructure. The account that assumes this role is private and has no access from the public internet.

## Step 1

### Click the quick add button

This button will run a hosted cloudformation stack on AWS which will create a new role in your account with the permissions required to provision infrastructure in Massdriver. The external ID for the role (required to prevent confused deputy attacks) will be auto populated in the CloudFormation stack. Do not change this value in the form to the left.

## Step 2

### Run the CloudFormation stack

The button will take you to the AWS console and allow you to approve of the resource creation. Click the "Create stack" button to provision the role.

![roles](/role-quick-add-1.PNG)

## Step 3

### Copy the role ARN to Massdriver

Once the CloudFormation stack has completed its task select the outputs tab and copy the value of the CustomProvisioningRoleArn output. Paste this value in to the form on the left in the field marked AWS ARN.

![roles](/quick-add-2.PNG)

## Step 4

Submit the role to Massdriver by clicking the save button and head to the [projects page](/projects) to begin provisioning infrastruture.
