# The pages are static, so the API address cannot be compiled in. It is written
# beside them as a one-line script at deploy time, and the browser loads it
# before the app code. Nothing has to be edited by hand when the API moves.
resource "aws_s3_object" "config" {
  bucket = aws_s3_bucket.site.id
  key    = "config.js"

  content      = "window.GAME_API = ${jsonencode(trimsuffix(var.api.endpoint, "/"))};\n"
  content_type = "text/javascript; charset=utf-8"

  # Config must not outlive a change of address in a visitor's cache.
  cache_control = "no-cache"

  depends_on = [aws_s3_bucket_server_side_encryption_configuration.site]
}
