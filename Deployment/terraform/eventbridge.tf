# =============================================================================
# EVENTBRIDGE CONFIGURATION
# =============================================================================
# This file defines EventBridge (CloudWatch Events) rules for scheduled execution
# Rules trigger Lambda functions on a regular schedule for automated data collection

# =============================================================================
# ENERGYLIVE DATA COLLECTION SCHEDULE
# =============================================================================
# Schedule for collecting energy consumption data from energyLIVE API

# EventBridge rule for energyLIVE data collection
resource "aws_cloudwatch_event_rule" "energylive_schedule" {
  name                = "${var.project_name}-energylive-schedule"
  description         = "Trigger energyLIVE data collection"
  schedule_expression = var.energylive_schedule_expression  # Default: every 5 minutes

  tags = {
    Name        = "EnergyLIVE Schedule"
    Description = "Scheduled trigger for energyLIVE data collection"
  }
}

# EventBridge target for energyLIVE Lambda
# Connects the schedule rule to the Lambda function
resource "aws_cloudwatch_event_target" "energylive_lambda_target" {
  rule      = aws_cloudwatch_event_rule.energylive_schedule.name
  target_id = "EnergyLIVELambdaTarget"  # Unique identifier for this target
  arn       = aws_lambda_function.energylive_collector.arn
}

# =============================================================================
# EPEX SPOT PRICE COLLECTION SCHEDULE
# =============================================================================
# Schedule for collecting electricity price data from EPEX Spot market

# EventBridge rule for EPEX Spot data collection
resource "aws_cloudwatch_event_rule" "epex_schedule" {
  name                = "${var.project_name}-epex-schedule"
  description         = "Trigger EPEX Spot price data collection"
  schedule_expression = var.epex_schedule_expression  # Default: every 15 minutes

  tags = {
    Name        = "EPEX Schedule"
    Description = "Scheduled trigger for EPEX Spot price data collection"
  }
}

# EventBridge target for EPEX Lambda
# Connects the schedule rule to the Lambda function
resource "aws_cloudwatch_event_target" "epex_lambda_target" {
  rule      = aws_cloudwatch_event_rule.epex_schedule.name
  target_id = "EPEXLambdaTarget"  # Unique identifier for this target
  arn       = aws_lambda_function.epex_collector.arn
} 