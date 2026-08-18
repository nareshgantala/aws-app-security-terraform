terraform {
  backend "s3" {
    bucket       = "roboshop-aws-terraform"
    key          = "aws-app-security-terraform/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}
