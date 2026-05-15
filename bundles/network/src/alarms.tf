# Stand-in alarms registered with Massdriver. Replace `cloud_resource_id` with
# the real CloudWatch / Azure Monitor / GCP Monitoring identifier (or
# Alertmanager rule URL) when this bundle deploys real infrastructure.

resource "massdriver_instance_alarm" "egress_throughput_anomaly" {
  display_name        = "Egress Throughput Anomaly"
  cloud_resource_id   = "demo:network:${random_pet.main.id}:egress-anomaly"
  threshold           = 1000000000 # 1 GB/s
  period              = 300
  comparison_operator = "GreaterThanThreshold"

  metric {
    name      = "BytesOut"
    namespace = "Demo/Network"
    statistic = "Sum"
    dimensions = {
      NetworkId = random_pet.main.id
    }
  }
}

resource "massdriver_instance_alarm" "nat_port_exhaustion" {
  display_name        = "NAT Port Exhaustion"
  cloud_resource_id   = "demo:network:${random_pet.main.id}:nat-ports"
  threshold           = 50000
  period              = 300
  comparison_operator = "GreaterThanThreshold"

  metric {
    name      = "ErrorPortAllocation"
    namespace = "Demo/Network"
    statistic = "Sum"
    dimensions = {
      NetworkId = random_pet.main.id
    }
  }
}
