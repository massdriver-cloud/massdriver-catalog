locals {
  image_name = var.registry.name
}

resource "github_repository" "app" {
  name        = var.repository_name
  description = var.description

  # Not optional. With neither visibility nor private set, the provider computes
  # "public" — forget it once and a team's source is on the open internet.
  visibility = var.visibility

  # Needed before any file can be written: a repository with no commits has no
  # branch to write to.
  auto_init = true

  # Offboarding archives rather than deletes. Unarchiving is one click; undeleting
  # is a support ticket, if it is possible at all.
  archive_on_destroy = true

  has_issues   = true
  has_projects = false
  has_wiki     = false
}

# A push identity scoped to exactly this one registry. Not an OIDC federation —
# see the runbook for why that is the better end state and what it costs.
resource "aws_iam_user" "ci" {
  name = "ci-${var.repository_name}"
  path = "/citizen-ci/"
}

resource "aws_iam_user_policy" "ci_push" {
  name = "push-to-${var.registry.name}"
  user = aws_iam_user.ci.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Fetching a login token is account-wide by design; the API takes no
        # resource. The grant that matters is the one below it.
        Sid      = "GetLoginToken"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid    = "PushToThisRepositoryOnly"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
        ]
        Resource = var.registry.arn
      },
    ]
  })
}

resource "aws_iam_access_key" "ci" {
  user = aws_iam_user.ci.name
}

resource "github_actions_secret" "aws_key_id" {
  repository      = github_repository.app.name
  secret_name     = "AWS_ACCESS_KEY_ID"
  plaintext_value = aws_iam_access_key.ci.id
}

resource "github_actions_secret" "aws_secret" {
  repository      = github_repository.app.name
  secret_name     = "AWS_SECRET_ACCESS_KEY"
  plaintext_value = aws_iam_access_key.ci.secret
}

# Variables rather than more secrets: none of these are sensitive, and keeping
# them out of the workflow file means the workflow never needs regenerating when
# a registry moves.
resource "github_actions_variable" "registry" {
  repository    = github_repository.app.name
  variable_name = "ECR_REGISTRY"
  value         = var.registry.url
}

resource "github_actions_variable" "region" {
  repository    = github_repository.app.name
  variable_name = "AWS_REGION"
  value         = var.registry.region
}

resource "github_actions_variable" "image_name" {
  repository    = github_repository.app.name
  variable_name = "IMAGE_NAME"
  value         = local.image_name
}

# The pipeline. Static, because everything that varies is an Actions variable.
resource "github_repository_file" "workflow" {
  repository          = github_repository.app.name
  file                = ".github/workflows/build.yaml"
  content             = file("${path.module}/files/build.yaml")
  commit_message      = "Add the build pipeline"
  overwrite_on_create = true
}

resource "github_repository_file" "dockerfile" {
  count = var.seed_starter_files ? 1 : 0

  repository          = github_repository.app.name
  file                = "Dockerfile"
  content             = file("${path.module}/files/Dockerfile")
  commit_message      = "Add a starting point"
  overwrite_on_create = true
}

resource "github_repository_file" "app" {
  count = var.seed_starter_files ? 1 : 0

  repository          = github_repository.app.name
  file                = "main.py"
  content             = file("${path.module}/files/main.py")
  commit_message      = "Add a starting point"
  overwrite_on_create = true
}

resource "github_repository_file" "readme" {
  count = var.seed_starter_files ? 1 : 0

  repository = github_repository.app.name
  file       = "README.md"
  content = templatefile("${path.module}/files/README.md.tftpl", {
    name     = var.repository_name
    registry = var.registry.url
  })
  commit_message      = "Add a starting point"
  overwrite_on_create = true
}
