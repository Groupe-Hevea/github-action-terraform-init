#!/usr/bin/env bash

set -euo pipefail
echo Show env :
env
echo "----"
echo show infos :
echo "show pwd : $(pwd)"
echo "show ls :"
ls
echo "---"
echo content from env var ROOT_DIR : $ROOT_DIR
ls -lRa $ROOT_DIR
echo "----"
if [ "$SKIP_PUSH" = "true" ]; then
  github-comment exec -- "$TF_COMMAND" init -input=false
  exit 0
fi

exist_lock_file=false
if [ -f .terraform.lock.hcl ]; then
  exist_lock_file=true
fi

"$TF_COMMAND" init -input=false || github-comment exec -- "$TF_COMMAND" init -input=false -upgrade

# shellcheck disable=SC2086
github-comment exec -- "$TF_COMMAND" providers lock $PROVIDERS_LOCK_OPTS
echo BEFORE git diff : git diff --quiet -C "$ROOT_DIR" "$ROOT_DIR/$WORKING_DIR/.terraform.lock.hcl"
git diff -C "$ROOT_DIR/$WORKING_DIR" .terraform.lock.hcl
if [ "$exist_lock_file" = "false" ] || ! git diff -C "$ROOT_DIR/$WORKING_DIR" .terraform.lock.hcl; then
	ghcp commit -r "$GITHUB_REPOSITORY" -b "$GITHUB_HEAD_REF" \
		-m "chore: update .terraform.lock.hcl" \
		-C "$ROOT_DIR" "$WORKING_DIR/.terraform.lock.hcl" \
		--token "$GITHUB_APP_TOKEN"
	exit 1
fi
echo AFTER git diff
