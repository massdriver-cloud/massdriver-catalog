# Environment variables handed to the function at runtime.
#
# This is the seam meant for editing. Lift values off your connections here —
# bucket names, database hostnames, queue URLs — so the function reads them from
# the environment instead of hardcoding them.
#
# These are encrypted at rest with the bundle's KMS key. Do not put secrets in
# params; use the platform's secret management instead.
locals {
  environment_variables = merge(
    {
      LOG_LEVEL = "info"
    },
    local.has_gateway ? {
      API_BASE_URL = var.gateway.endpoint
    } : {},
  )
}
