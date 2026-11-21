output "tfstate_bucket_name" {
  description = "Tên S3 bucket – dùng điền vào terraform/backend.tf"
  value       = aws_s3_bucket.tfstate.bucket
}

output "tfstate_bucket_arn" {
  value = aws_s3_bucket.tfstate.arn
}
