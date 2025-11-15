#!/usr/bin/env bash

# Common library for loading restic environment from .env files
# Usage: load_restic_env <env-file-path>

load_restic_env() {
  local env_file="$1"

  if [ -z "${env_file}" ]; then
    echo "Error: No env file provided" >&2
    return 1
  fi

  # Load the .env file
  . "${env_file}"

  # Check if RESTIC_REPOSITORY is set
  if [ -z "${RESTIC_REPOSITORY:-}" ]; then
    echo "Error: RESTIC_REPOSITORY is not set" >&2
    return 1
  fi

  # Export credentials based on repository type
  if [[ "${RESTIC_REPOSITORY}" == b2:* ]]; then
    export B2_ACCOUNT_ID
    export B2_ACCOUNT_KEY
  elif [[ "${RESTIC_REPOSITORY}" == s3:* ]]; then
    export AWS_ACCESS_KEY_ID
    export AWS_SECRET_ACCESS_KEY
  else
    echo "Error: Unknown repository type: ${RESTIC_REPOSITORY}" >&2
    return 1
  fi

  export RESTIC_REPOSITORY
  export RESTIC_PASSWORD_FILE
}
