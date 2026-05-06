variable "env" {
  type        = string
  description = "Entorno de despliegue: dev, qa o prod"

  validation {
    condition     = contains(["dev", "qa", "prod"], var.env)
    error_message = "env debe ser uno de: dev, qa, prod."
  }
}

variable "aws_region" {
  type        = string
  description = "Región de AWS"
  default     = "us-east-1"
}

variable "suffix" {
  type        = string
  description = "Sufijo único corto que se añade a los nombres de recursos globales (ej. bucket S3)"
}

variable "upload_lambda_memory_mb" {
  type        = number
  description = "Memoria en MB para la Lambda de carga"
  default     = 256
}

variable "crop_lambda_memory_mb" {
  type        = number
  description = "Memoria en MB para la Lambda de recorte"
  default     = 512
}

variable "log_retention_days" {
  type        = number
  description = "Días de retención de logs en CloudWatch"
  default     = 14
}

variable "sqs_visibility_timeout_seconds" {
  type        = number
  description = "Timeout de visibilidad SQS (debe ser >= 6x el timeout de la Lambda)"
  default     = 360
}

variable "sqs_max_receive_count" {
  type        = number
  description = "Intentos máximos de recepción SQS antes de enviar a DLQ"
  default     = 3
}

