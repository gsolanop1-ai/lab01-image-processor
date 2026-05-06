# Endpoint Gateway de S3 (gratuito), sin ENI, inyectado en tablas de rutas privadas
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = aws_route_table.private[*].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = "*"
      Action    = ["s3:GetObject", "s3:PutObject"]
      Resource  = "arn:aws:s3:::${local.bucket_name}/*"
    }]
  })

  tags = { Name = "${local.name_prefix}-vpce-s3" }
}

# Endpoint Interface de SQS — ENI por AZ, DNS privado habilitado
resource "aws_vpc_endpoint" "sqs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.sqs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpce_sqs.id]
  private_dns_enabled = true

  tags = { Name = "${local.name_prefix}-vpce-sqs" }
}