# LAB01 — Procesador de Imágenes Serverless con Terraform en AWS

Arquitectura serverless que permite subir imágenes vía HTTP y procesarlas automáticamente (recorte circular 40×40 px) usando AWS Lambda, S3 y SQS. Toda la infraestructura está definida como código con Terraform y soporta tres entornos independientes: **DEV**, **QA** y **PROD**.

---

## ¿Cómo funciona?

```
Cliente
  └─► API Gateway (POST /upload, HTTPS)
        └─► upload-lambda (Node.js 20)
              └─► S3 uploads/
                    └─► SQS Queue (evento automático)
                          └─► crop-lambda (Node.js 20)
                                └─► S3 processed/ (PNG circular 40x40)
```

1. El cliente envía una imagen por HTTP (multipart o JSON+base64)
2. `upload-lambda` valida el formato y tamaño (máx. 10 MB, tipos: jpg, png, gif, webp) y la guarda en S3
3. S3 dispara un evento a SQS automáticamente
4. `crop-lambda` consume el mensaje, recorta la imagen en círculo de 40×40 px y guarda el resultado en `processed/`

---

## Servicios AWS utilizados

| Servicio | Rol |
|---|---|
| API Gateway HTTP API v2 | Entrada HTTPS para subida de imágenes |
| Lambda `upload` | Valida y almacena imagen original |
| Lambda `crop` | Recorta imagen a círculo 40×40 PNG |
| S3 Bucket | Almacena originales (30 días) y procesadas (90 días) |
| SQS + DLQ | Desacopla upload de crop; reintentos y cola de fallos |
| VPC + NAT Gateways | Lambdas en red privada con salida controlada |
| VPC Endpoints | Tráfico a S3 y SQS sin pasar por internet |
| IAM Roles | Permisos mínimos por función |
| CloudWatch | Logs de ejecución y alarma en DLQ |

---

## Estructura del repositorio

```
.
├── iac/
│   ├── provider.tf          # Proveedor AWS y versiones de Terraform
│   ├── variables.tf         # Variables parametrizables por entorno
│   ├── locals.tf            # Prefijos y nombres calculados
│   ├── outputs.tf           # Salidas: URL del API, bucket, colas
│   ├── vpc.tf               # VPC, subredes, IGW, NAT, tablas de rutas
│   ├── security_groups.tf   # SGs para Lambdas y endpoint SQS
│   ├── vpc_endpoints.tf     # S3 Gateway Endpoint + SQS Interface Endpoint
│   ├── s3.tf                # Bucket con versionado, SSE y ciclo de vida
│   ├── sqs.tf               # Cola principal + DLQ + política S3
│   ├── iam.tf               # Roles IAM con mínimo privilegio
│   ├── cloudwatch.tf        # Grupos de logs y alarma DLQ
│   ├── lambda.tf            # Funciones Lambda + build npm + mapeo SQS
│   ├── api_gateway.tf       # HTTP API v2 + ruta POST /upload
│   └── envs/
│       ├── dev.tfvars       # Variables para DEV
│       ├── qa.tfvars        # Variables para QA
│       └── prod.tfvars      # Variables para PROD
└── src/
    ├── upload-lambda/
    │   ├── index.js         # Recibe imagen, valida y sube a S3
    │   └── package.json
    └── crop-lambda/
        ├── index.js         # Descarga, recorta en círculo y guarda
        └── package.json
```

---

## Requisitos previos

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5.0
- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
- [Node.js](https://nodejs.org/) >= 18 y npm >= 9
- Cuenta AWS con permisos para crear Lambda, S3, SQS, VPC, IAM, API Gateway y CloudWatch

---

## Despliegue

### 1. Configurar credenciales AWS

```bash
aws configure
# AWS Access Key ID:     <tu-access-key>
# AWS Secret Access Key: <tu-secret-key>
# Default region:        us-east-1
# Output format:         json
```

Verificar:
```bash
aws sts get-caller-identity
```

### 2. Inicializar Terraform

```bash
cd iac
terraform init
```

### 3. Desplegar un entorno

```bash
# DEV
terraform apply -var-file=envs/dev.tfvars

# QA
terraform apply -var-file=envs/qa.tfvars

# PROD
terraform apply -var-file=envs/prod.tfvars
```

Al finalizar, Terraform muestra las salidas:
```
api_endpoint   = "https://xxxx.execute-api.us-east-1.amazonaws.com"
upload_url     = "https://xxxx.execute-api.us-east-1.amazonaws.com/upload"
s3_bucket_name = "image-processor-dev-images-lab01"
```

---

## Probar el endpoint

```bash
# JSON + base64
curl -X POST https://<tu-api-url>/upload \
  -H "Content-Type: application/json" \
  -d '{"image": "data:image/png;base64,<base64>", "name": "foto.png"}'

# Respuesta esperada
{"message":"Upload successful","fileId":"uuid","key":"uploads/uuid.png"}
```

Verificar resultado en S3:
```bash
aws s3 ls s3://image-processor-dev-images-lab01/processed/
```

Ver logs en tiempo real:
```bash
aws logs tail /aws/lambda/image-processor-dev-crop --follow
```

---

## Destruir recursos

```bash
# Vaciar el bucket primero (si subiste imágenes)
aws s3 rm s3://image-processor-dev-images-lab01 --recursive

# Destruir la infraestructura
terraform destroy -var-file=envs/dev.tfvars
```

---

## Diferencias entre entornos

| Parámetro | DEV | QA | PROD |
|---|---|---|---|
| Memoria upload-lambda | 256 MB | 256 MB | 512 MB |
| Memoria crop-lambda | 512 MB | 512 MB | 1024 MB |
| Retención de logs | 14 días | 14 días | 30 días |

---

## Notas

- El bucket S3 es completamente privado — sin acceso público.
- Las Lambdas corren en subredes privadas; usan NAT Gateway para CloudWatch y VPC Endpoints para S3/SQS.
- El campo `suffix` en los `.tfvars` debe ser único por cuenta AWS (evita conflictos de nombre en S3).
- Si el `terraform destroy` falla en el bucket, vaciarlo manualmente con `aws s3 rm` y volver a ejecutar.
```