ops-demos-snowflake

do the ops demo, then see if claude can feature dev a whole bundle given an env w/ a credential and the massdriver skill

## 0

api.massdriver.mdawssbx.com/auth/quickstart

## 1.

## 2.

git clone git@github.com:massdriver-cloud/massdriver-catalog.git
make

## 3.

open https://app.massdriver.mdawssbx.com/orgs/demo/credentials

## 4.
_Maybe mad lib about UI, CLI or API_

mass prj create api --name "My API Project"
mass env create api-staging --name "Staging"
mass pkg create api-staging-network --bundle network --name "Shared VPC Subnet"
open https://app.massdriver.mdawssbx.com/orgs/demo/projects/api/environments/staging

**Continue adding and linking in UI**

_Kickoff env deployment behind the scenes_

## 5.

cd platforms/snowflake
mass def publish ./massdriver.yaml
open https://app.massdriver.mdawssbx.com/orgs/demo/credentials?create=catalog-demo/snowflake-credentials

**Add a fake credential**

## 6.

cd ../../bundles/snowflake-database
mass bundle publish

_TODO: open its repo link at end_

## 7.

cd ../application

_developer adds:_
```
sfdb:
  $ref: snowflake-database
```

mass bundle publish

## 8.

open https://app.massdriver.mdawssbx.com/orgs/demo/projects/api/environments/staging

_view package panel and add a recommendation, configure_

## 9.

deploy -> cut back to the repo view, full circle visibility
