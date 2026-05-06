resource "aws_security_group" "upload_lambda" {
  name        = "${local.name_prefix}-sg-upload-lambda"
  description = "upload-lambda: sin entrada, salida HTTPS hacia endpoint S3 y NAT"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS hacia endpoint Gateway S3 y CloudWatch Logs via NAT"
  }

  tags = { Name = "${local.name_prefix}-sg-upload-lambda" }
}

resource "aws_security_group" "crop_lambda" {
  name        = "${local.name_prefix}-sg-crop-lambda"
  description = "crop-lambda: sin entrada, salida HTTPS hacia endpoints S3 y SQS"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS hacia endpoint Gateway S3, endpoint Interface SQS y NAT"
  }

  tags = { Name = "${local.name_prefix}-sg-crop-lambda" }
}

resource "aws_security_group" "vpce_sqs" {
  name        = "${local.name_prefix}-sg-vpce-sqs"
  description = "Endpoint VPC Interface de SQS: permite HTTPS desde SGs de Lambda"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.upload_lambda.id, aws_security_group.crop_lambda.id]
    description     = "Permite que las funciones Lambda alcancen el endpoint interface de SQS"
  }

  tags = { Name = "${local.name_prefix}-sg-vpce-sqs" }
}