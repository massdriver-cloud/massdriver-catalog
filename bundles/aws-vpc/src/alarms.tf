# Registered with Massdriver's alarm system; thresholds surface on the
# instance's health panel in the UI.

resource "massdriver_instance_alarm" "nat_port_exhaustion" {
  count = local.nat_gateway_count

  display_name        = "NAT Port Exhaustion (${local.azs[count.index]})"
  cloud_resource_id   = aws_nat_gateway.main[count.index].id
  threshold           = 1
  period              = 300
  comparison_operator = "GreaterThanOrEqualToThreshold"

  metric {
    name      = "ErrorPortAllocation"
    namespace = "AWS/NATGateway"
    statistic = "Sum"
    dimensions = {
      NatGatewayId = aws_nat_gateway.main[count.index].id
    }
  }
}
