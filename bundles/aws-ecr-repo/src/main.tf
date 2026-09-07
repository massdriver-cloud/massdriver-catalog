data "aws_caller_identity" "current" {}

resource "aws_ecr_repository" "main" {
  name                 = var.repository_name
  image_tag_mutability = var.immutable_tags ? "IMMUTABLE" : "MUTABLE"

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  # AWS-managed keys. A team registry holds build output, not secrets, and a
  # customer-managed key here buys nothing you cannot get from the account.
  encryption_configuration {
    encryption_type = "AES256"
  }

  # Deliberately allowed. This registry belongs to one team, its contents are
  # rebuildable from their source, and refusing to delete a registry full of
  # stale images turns offboarding into a support ticket.
  force_delete = true
}

# Storage grows forever without this, and nobody notices until the bill does.
resource "aws_ecr_lifecycle_policy" "keep_recent" {
  repository = aws_ecr_repository.main.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep the last ${var.keep_last_images} images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.keep_last_images
        }
        action = { type = "expire" }
      }
    ]
  })
}
