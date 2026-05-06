output "api_endpoint" {
  description = "URL base del API Gateway"
  value       = aws_apigatewayv2_api.main.api_endpoint
}

output "upload_url" {
  description = "URL completa para llamar POST /upload"
  value       = "${aws_apigatewayv2_stage.default.invoke_url}/upload"
}

output "s3_bucket_name" {
  description = "Nombre del bucket S3 de imágenes"
  value       = aws_s3_bucket.images.bucket
}

output "sqs_queue_url" {
  description = "URL de la cola SQS principal"
  value       = aws_sqs_queue.main.url
}

output "sqs_dlq_url" {
  description = "URL de la cola de mensajes muertos (DLQ)"
  value       = aws_sqs_queue.dlq.url
}

output "upload_lambda_name" {
  description = "Nombre de la función Lambda de carga"
  value       = aws_lambda_function.upload.function_name
}

output "crop_lambda_name" {
  description = "Nombre de la función Lambda de recorte"
  value       = aws_lambda_function.crop.function_name
}
