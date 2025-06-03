# EventBridge rule for energyLIVE data collection
resource "aws_cloudwatch_event_rule" "energylive_schedule" {
  name                = "${var.project_name}-energylive-schedule"
  description         = "Trigger energyLIVE data collection"
  schedule_expression = var.energylive_schedule_expression

  tags = {
    Name        = "EnergyLIVE Schedule"
    Description = "Scheduled trigger for energyLIVE data collection"
  }
}

# EventBridge target for energyLIVE Lambda
resource "aws_cloudwatch_event_target" "energylive_lambda_target" {
  rule      = aws_cloudwatch_event_rule.energylive_schedule.name
  target_id = "EnergyLIVELambdaTarget"
  arn       = aws_lambda_function.energylive_collector.arn
}

# EventBridge rule for EPEX Spot data collection
resource "aws_cloudwatch_event_rule" "epex_schedule" {
  name                = "${var.project_name}-epex-schedule"
  description         = "Trigger EPEX Spot price data collection"
  schedule_expression = var.epex_schedule_expression

  tags = {
    Name        = "EPEX Schedule"
    Description = "Scheduled trigger for EPEX Spot price data collection"
  }
}

# EventBridge target for EPEX Lambda
resource "aws_cloudwatch_event_target" "epex_lambda_target" {
  rule      = aws_cloudwatch_event_rule.epex_schedule.name
  target_id = "EPEXLambdaTarget"
  arn       = aws_lambda_function.epex_collector.arn
} 