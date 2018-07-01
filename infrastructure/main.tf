variable project_name {}
variable domain {}

provider aws {
  region = "ap-southeast-2"
}

provider aws {
  region = "us-east-1"
  alias = "us-east-1"
}

terraform {
  backend s3 {
    region = "ap-southeast-2"
    key = "kaidenplayer/state.tfstate"
    bucket = "terraform-state-20180701090834187200000002"
  }
}

data aws_route53_zone hosted_zone {
  name = "${var.domain}"
}

resource aws_route53_record frontend_endpoint {
  name = "${terraform.workspace == "production" ? var.domain : "${terraform.workspace}.${var.domain}"}"
  type = "A"
  zone_id = "${data.aws_route53_zone.hosted_zone.zone_id}"

  alias {
    name = "${aws_cloudfront_distribution.s3_dist.domain_name}"
    zone_id = "${aws_cloudfront_distribution.s3_dist.hosted_zone_id}"
    evaluate_target_health = false
  }
}

resource aws_acm_certificate cert {
  domain_name = "${terraform.workspace == "production" ? var.domain : "${terraform.workspace}.${var.domain}"}"
  validation_method = "DNS"
  provider = "aws.us-east-1"
}

resource aws_route53_record cert_validation {
  zone_id = "${data.aws_route53_zone.hosted_zone.zone_id}"
  name = "${aws_acm_certificate.cert.domain_validation_options.0.resource_record_name}"
  type = "${aws_acm_certificate.cert.domain_validation_options.0.resource_record_type}"
  ttl = 60
  records = [
    "${aws_acm_certificate.cert.domain_validation_options.0.resource_record_value}"
  ]
  provider = "aws.us-east-1"
}

resource aws_acm_certificate_validation cert_validation {
  certificate_arn = "${aws_acm_certificate.cert.arn}"
  validation_record_fqdns = [
    "${aws_route53_record.cert_validation.fqdn}"
  ]
  provider = "aws.us-east-1"
}

resource aws_s3_bucket site {
  bucket_prefix = "${terraform.workspace}-${var.project_name}-site-"
  acl = "public-read"

  website {
    index_document = "index.html"
    error_document = "index.html"
  }

  tags {
    Name = "Re-Frame site"
  }
  force_destroy = true
}

resource aws_cloudfront_distribution s3_dist {
  origin {
    domain_name = "${aws_s3_bucket.site.bucket_domain_name}"
    origin_id = "${terraform.workspace}-${var.project_name}-site-origin"
  }

  depends_on = [
    "aws_acm_certificate_validation.cert_validation"
  ]

  aliases = [
    "${terraform.workspace == "production" ? var.domain : "${terraform.workspace}.${var.domain}"}"
  ]

  enabled = true
  is_ipv6_enabled = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods =  ["HEAD", "DELETE", "POST", "GET", "OPTIONS", "PUT", "PATCH"]
    cached_methods = ["GET", "HEAD"]
    target_origin_id = "${terraform.workspace}-${var.project_name}-site-origin"

    forwarded_values {
      cookies {
        forward = "none"
      }
      query_string = true
    }

    viewer_protocol_policy = "redirect-to-https"
    max_ttl = 86400
    default_ttl = 3600
    min_ttl = 0
  }

  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations = ["AU"]
    }

  }

  viewer_certificate {
    acm_certificate_arn = "${aws_acm_certificate.cert.arn}"
    ssl_support_method = "sni-only"
    minimum_protocol_version = "TLSv1"
  }

  custom_error_response {
    error_code = 404
    response_code = 200
    response_page_path = "/index.html"
  }
}

output website_distribution_id {
  value = "${aws_cloudfront_distribution.s3_dist.id}"
}

output website_bucket_name {
  value = "${aws_s3_bucket.site.id}"
}
