# Pasos de build (se ejecuta npm install antes de empaquetar)

resource "null_resource" "build_upload" {
  triggers = {
    package = filemd5("${path.module}/../src/upload-lambda/package.json")
    source  = filemd5("${path.module}/../src/upload-lambda/index.js")
  }
  provisioner "local-exec" {
    working_dir = "${path.module}/../src/upload-lambda"
    command     = "npm install --omit=dev"
  }
}

resource "null_resource" "build_crop" {
  triggers = {
    package = filemd5("${path.module}/../src/crop-lambda/package.json")
    source  = filemd5("${path.module}/../src/crop-lambda/index.js")
  }
  # Las flags --os/--cpu fuerzan a npm a descargar el binario precompilado de sharp para Linux x64
  provisioner "local-exec" {
    working_dir = "${path.module}/../src/crop-lambda"
    command     = "npm install --omit=dev --os=linux --cpu=x64 --libc=glibc"
  }
}

# Archivos ZIP 

data "archive_file" "upload_lambda" {
  depends_on  = [null_resource.build_upload]
  type        = "zip"
  source_dir  = "${path.module}/../src/upload-lambda"
  output_path = "${path.module}/../dist/upload-lambda.zip"
  excludes    = [".DS_Store", "*.map"]
}

data "archive_file" "crop_lambda" {
  depends_on  = [null_resource.build_crop]
  type        = "zip"
  source_dir  = "${path.module}/../src/crop-lambda"
  output_path = "${path.module}/../dist/crop-lambda.zip"
  excludes    = [".DS_Store", "*.map"]
}

# Funciones Lambda

resource "aws_lambda_function" "upload" {
  function_name    = "${local.name_prefix}-upload"
  role             = aws_iam_role.upload_lambda.arn
  runtime          = "nodejs20.x"
  handler          = "index.handler"
  memory_size      = var.upload_lambda_memory_mb
  timeout          = 30
  filename         = data.archive_file.upload_lambda.output_path
  source_code_hash = data.archive_file.upload_lambda.output_base64sha256

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.upload_lambda.id]
  }

  environment {
    variables = {
      S3_BUCKET     = aws_s3_bucket.images.bucket
      UPLOAD_PREFIX = "uploads/"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.upload_basic_exec,
    aws_iam_role_policy_attachment.upload_vpc_exec,
    aws_cloudwatch_log_group.upload_lambda,
  ]
}

resource "aws_lambda_function" "crop" {
  function_name    = "${local.name_prefix}-crop"
  role             = aws_iam_role.crop_lambda.arn
  runtime          = "nodejs20.x"
  handler          = "index.handler"
  memory_size      = var.crop_lambda_memory_mb
  timeout          = 60
  filename         = data.archive_file.crop_lambda.output_path
  source_code_hash = data.archive_file.crop_lambda.output_base64sha256

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.crop_lambda.id]
  }

  environment {
    variables = {
      S3_BUCKET        = aws_s3_bucket.images.bucket
      PROCESSED_PREFIX = "processed/"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.crop_basic_exec,
    aws_iam_role_policy_attachment.crop_vpc_exec,
    aws_cloudwatch_log_group.crop_lambda,
  ]
}

# Mapeo de origen de eventos SQS → crop-lambda 

resource "aws_lambda_event_source_mapping" "sqs_to_crop" {
  event_source_arn        = aws_sqs_queue.main.arn
  function_name           = aws_lambda_function.crop.arn
  batch_size              = 5
  function_response_types = ["ReportBatchItemFailures"]
  enabled                 = true
}

# Permiso para que API Gateway invoque upload-lambda 

resource "aws_lambda_permission" "apigw_upload" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.upload.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*/upload"
}
