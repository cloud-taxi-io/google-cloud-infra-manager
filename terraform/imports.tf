# One-shot import: Identity Platform was initialized before Terraform managed it, so
# `create` fails with "Identity Platform has already been enabled for this project".
# The id must be a literal on Terraform 1.5 (Infra Manager default).
# TODO: remove this file after the first successful apply.
import {
  to = google_identity_platform_config.default
  id = "projects/gen-lang-client-0031150958/config"
}
