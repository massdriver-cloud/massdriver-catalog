# This app template doesn't emit a resource by default — nothing downstream
# consumes an app's own output in this catalog. If a real app needs to expose
# something (e.g. a webhook URL for another service to call), add a
# massdriver_resource block here and declare it under `artifacts:` in
# massdriver.yaml.
