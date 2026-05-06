locals {
  name_prefix = "image-processor-${var.env}"
  bucket_name = "image-processor-${var.env}-images-${var.suffix}"

  azs = ["${var.aws_region}a", "${var.aws_region}b"]

  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
}
