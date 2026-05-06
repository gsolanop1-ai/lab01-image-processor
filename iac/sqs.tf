# Cola de mensajes muertos (Dead-Letter Queue)
resource "aws_sqs_queue" "dlq" {
  name                      = "${local.name_prefix}-image-dlq"
  message_retention_seconds = 14 * 24 * 60 * 60 # 14 días

  tags = { Name = "${local.name_prefix}-image-dlq" }
}

# Cola principal
resource "aws_sqs_queue" "main" {
  name                       = "${local.name_prefix}-image-queue"
  visibility_timeout_seconds = var.sqs_visibility_timeout_seconds
  message_retention_seconds  = 86400 # 1 día
  receive_wait_time_seconds  = 20    # long polling

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.sqs_max_receive_count
  })

  tags = { Name = "${local.name_prefix}-image-queue" }
}

# Permite a S3 enviar notificaciones ObjectCreated a la cola principal
resource "aws_sqs_queue_policy" "main" {
  queue_url = aws_sqs_queue.main.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowS3SendMessage"
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.main.arn
      Condition = {
        ArnLike = {
          "aws:SourceArn" = aws_s3_bucket.images.arn
        }
      }
    }]
  })
}
