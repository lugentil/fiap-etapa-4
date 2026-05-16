resource "aws_sqs_queue" "main" {
  name                       = "${var.project_name}-evaluation-events"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 86400
  receive_wait_time_seconds  = 20

  tags = {
    Name = "${var.project_name}-sqs"
  }
}
