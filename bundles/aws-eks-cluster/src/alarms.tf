# Registered with Massdriver's alarm system; thresholds surface on the
# instance's health panel in the UI.

# EKS publishes control plane metrics to the AWS/EKS namespace by default (no
# Container Insights opt-in needed). etcd has a hard 8 GiB storage limit — once
# it fills, the cluster goes read-only. Alarm at 6 GiB to leave room to react.
resource "massdriver_instance_alarm" "control_plane_storage" {
  display_name        = "Control Plane Storage Nearly Full"
  cloud_resource_id   = aws_eks_cluster.main.arn
  threshold           = 6442450944 # 6 GiB of the 8 GiB etcd limit
  period              = 300
  comparison_operator = "GreaterThanOrEqualToThreshold"

  metric {
    name      = "apiserver_storage_size_bytes"
    namespace = "AWS/EKS"
    statistic = "Maximum"
    dimensions = {
      ClusterName = aws_eks_cluster.main.name
    }
  }
}
