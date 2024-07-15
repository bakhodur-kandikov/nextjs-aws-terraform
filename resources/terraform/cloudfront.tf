resource "aws_s3_bucket_policy" "s3_static_allow_cloudfront" {
  bucket = aws_s3_bucket.nextapp_static.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action = "s3:GetObject"
        Resource = "${aws_s3_bucket.nextapp_static.arn}/*",
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = "${aws_cloudfront_distribution.nextapp_distribution.arn}"
          }
        }
      }
    ]
  })
}

# CloudFront Origin Access Control
resource "aws_cloudfront_origin_access_control" "oac" {
  name = "AllowCloudFrontS3NextStatic"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

locals {
  s3_origin_id = aws_s3_bucket.nextapp_static.id
  nextapp_server_origin = "nextapp_server"
}

# Define the CloudFront distribution
resource "aws_cloudfront_distribution" "nextapp_distribution" {

  depends_on = [ aws_vpc.main, aws_instance.nextapp_server, aws_s3_bucket.nextapp_static ]
  origin {
    domain_name = aws_instance.nextapp_server.public_dns
    origin_id   = local.nextapp_server_origin

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }
  origin {
    domain_name = aws_s3_bucket.nextapp_static.bucket_domain_name
    origin_id   = local.s3_origin_id
    origin_access_control_id   = aws_cloudfront_origin_access_control.oac.id
  }

  enabled             = true
  is_ipv6_enabled     = true

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.nextapp_server_origin
    # Cache Disabled Policy
    cache_policy_id  = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  ordered_cache_behavior {
    path_pattern     = "/_next/static/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.s3_origin_id

    # Cache Optimized Policy
    cache_policy_id  = "658327ea-f89d-4fab-a63d-7e88639e58f6"

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }
  ordered_cache_behavior {
    path_pattern     = "/public/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.s3_origin_id

    # Cache Optimized Policy
    cache_policy_id  = "658327ea-f89d-4fab-a63d-7e88639e58f6"

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

output "cf_distribution_name" {
  value = aws_cloudfront_distribution.nextapp_distribution.domain_name
}