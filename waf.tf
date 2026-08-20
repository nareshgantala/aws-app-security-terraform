# 1. Define the WAF Web ACL to block /blocked
resource "aws_wafv2_web_acl" "example" {
  name        = "aws-app-security-terraform-web-acl"
  description = "WAF to block a specific URI path"
  scope       = "REGIONAL"

  # Default action is to allow traffic unless it matches a rule
  default_action {
    allow {}
  }

  rule {
    name     = "block-uri-rule"
    priority = 1

    # Action to take when the rule matches
    action {
      block {}
    }

    # Statement to look for /blocked in the URI path
    statement {
      byte_match_statement {
        field_to_match {
          uri_path {}
        }
        positional_constraint = "EXACTLY"
        search_string         = "/blocked"

        # Ensures minor formatting variations don't bypass the rule
        text_transformation {
          priority = 0
          type     = "NONE"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "BlockURIRuleMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "WAFALBMetric"
    sampled_requests_enabled   = true
  }
}

# 2. Associate the WAF with your existing ALB
resource "aws_wafv2_web_acl_association" "example" {
  resource_arn = aws_lb.app_alb.arn
  web_acl_arn  = aws_wafv2_web_acl.example.arn
}
