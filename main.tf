terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.49.0"
    }
  }
}


provider "aws" {
  region = var.aws_region
}

data "tls_certificate" "tfc_certificate" {
  url = "https://${var.tfc_hostname}"
}



resource "aws_iam_openid_connect_provider" "tfc_provider" {
  url             = data.tls_certificate.tfc_certificate.url
  client_id_list  = [var.tfc_aws_audience]
  thumbprint_list = [data.tls_certificate.tfc_certificate.certificates[0].sha1_fingerprint]
}

resource "aws_iam_role" "tfc_role" {
  name = "tfc-role"

  assume_role_policy = templatefile("${path.module}/templates/trust_policy.json", {
    oid_provider_arn = aws_iam_openid_connect_provider.tfc_provider.arn
    hostname         = var.tfc_hostname
    client_id        = one(aws_iam_openid_connect_provider.tfc_provider.client_id_list)
    organization     = var.tfc_organization_name
    project          = var.tfc_project_name
    workspace        = var.tfc_workspace_name
  })
}

resource "aws_iam_policy" "tfc_policy" {
  name        = "tfc-policy"
  description = "TFC run policy"

  policy = file("${path.module}/templates/tfc_policy.json")
}

resource "aws_iam_role_policy_attachment" "tfc_policy_attachment" {
  role       = aws_iam_role.tfc_role.name
  policy_arn = aws_iam_policy.tfc_policy.arn
}
