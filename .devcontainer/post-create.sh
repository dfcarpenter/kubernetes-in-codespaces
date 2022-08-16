#!/bin/bash

# this runs at Codespace creation - not part of pre-build

echo "post-create start"
echo "$(date)    post-create start" >> "$HOME/status"

# update the repos
git -C /workspaces/imdb-app pull
git -C /workspaces/webvalidate pull


echo "adding az cli extensions"
az extension add --name connectedk8s
az extension add -n k8s-extension
az extension add --name k8s-configuration

export GITHUB_TOKEN="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"


echo "post-create complete"
echo "$(date +'%Y-%m-%d %H:%M:%S')    post-create complete" >> "$HOME/status"


