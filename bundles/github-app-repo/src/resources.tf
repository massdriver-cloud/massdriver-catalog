resource "massdriver_resource" "repository" {
  field = "repository"
  name  = "GitHub ${github_repository.app.full_name}"

  resource = jsonencode({
    full_name = github_repository.app.full_name
    url       = github_repository.app.html_url
    clone_url = github_repository.app.http_clone_url
    # The provider deprecated default_branch on the repository. auto_init is on,
    # so GitHub creates it from the organization's default-branch setting.
    default_branch = "main"
  })
}
