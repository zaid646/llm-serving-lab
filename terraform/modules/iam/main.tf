# CI/CD deploy role (least privilege) + IRSA-style OIDC trust for the K8s SA.
# Both the OIDC provider and the deploy role are gated so LocalStack Community
# (which lacks OIDC/EKS) can still plan the module with them disabled.

resource "aws_iam_openid_connect_provider" "cluster" {
  count = var.create_oidc_provider ? 1 : 0

  url             = var.oidc_issuer_url
  client_id_list  = var.oidc_client_ids
  thumbprint_list = var.oidc_thumbprints
}

data "aws_iam_policy_document" "ci_deploy_assume_role" {
  count = var.create_iam_role && var.create_oidc_provider ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.cluster[0].arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringLike"
      variable = "${replace(var.oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${var.k8s_namespace}:${var.k8s_service_account}"]
    }
  }
}

resource "aws_iam_role" "ci_deploy" {
  count = var.create_iam_role ? 1 : 0

  name               = "${var.name_prefix}-ci-deploy"
  assume_role_policy = var.create_oidc_provider ? data.aws_iam_policy_document.ci_deploy_assume_role[0].json : "{}"
  tags               = var.tags
}

resource "aws_iam_role_policy" "ci_deploy" {
  count = var.create_iam_role ? 1 : 0

  name   = "${var.name_prefix}-ci-deploy-policy"
  role   = aws_iam_role.ci_deploy[0].id
  policy = data.aws_iam_policy_document.ci_deploy_policy[0].json
}

data "aws_iam_policy_document" "ci_deploy_policy" {
  # checkov:skip=CKV_AWS_356:eks:DescribeCluster/ListClusters do not support
  # resource-level ARNs; "*" is required by the EKS API.
  count = var.create_iam_role ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:PutObjectAcl",
      "s3:ListBucket",
    ]
    resources = [
      module.model_artifacts_bucket.bucket_arn,
      "${module.model_artifacts_bucket.bucket_arn}/*",
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "eks:DescribeCluster",
      "eks:ListClusters",
    ]
    resources = ["*"]
  }
}

# Source bucket referenced by the least-privilege policy above.
module "model_artifacts_bucket" {
  source = "../../modules/s3"

  bucket_name = var.model_artifacts_bucket
  tags        = var.tags
}
