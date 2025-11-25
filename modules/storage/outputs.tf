output "bucket_name" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.main.bucket
}

output "bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.main.arn
}

output "website_url" {
  description = "S3 website URL"
  value       = aws_s3_bucket_website_configuration.main.website_endpoint
}