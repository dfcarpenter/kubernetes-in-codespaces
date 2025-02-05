#!/bin/bash

# this runs as part of pre-build

echo "on-create start"
echo "$(date +'%Y-%m-%d %H:%M:%S')    on-create start" >> "$HOME/status"

# clone repos
git clone https://github.com/cse-labs/imdb-app /workspaces/imdb-app
git clone https://github.com/microsoft/webvalidate /workspaces/webvalidate
git clone https://github.com/dfcarpenter/flux2-kustomize-azarc.git /workspaces/gitops-flux-azarc
git clone https://github.com/Azure/arc-cicd-demo-src /workspaces/arc-gitops/arc-cicd-demo-src 
git clone https://github.com/Azure/arc-cicd-demo-gitops /workspaces/arc-gitops/arc-cicd-demo-gitops
git clone https://github.com/dfcarpenter/gitops-flux2-kustomize-helm-mt /workspaces/gitops-flux2-kustomize-helm-mt 

# restore the repos
dotnet restore /workspaces/webvalidate/src/webvalidate.sln
dotnet restore /workspaces/imdb-app/src/imdb.csproj

export REPO_BASE=$PWD
export PATH="$PATH:$REPO_BASE/cli"

mkdir -p "$HOME/.ssh"

{
    # add cli to path
    echo "export PATH=\$PATH:$REPO_BASE/cli"

    echo "export REPO_BASE=$REPO_BASE"
    echo "compinit"
} >> "$HOME/.zshrc"

# create local registry
docker network create k3d
k3d registry create registry.localhost --port 5500
docker network connect k3d k3d-registry.localhost

# update the base docker images
docker pull mcr.microsoft.com/dotnet/aspnet:6.0-alpine
docker pull mcr.microsoft.com/dotnet/sdk:6.0
docker pull ghcr.io/cse-labs/webv-red:latest

# echo "dowloading kic CLI"
# cd cli || exit
# tag="0.4.3"
# wget -O kic.tar.gz "https://github.com/retaildevcrews/akdc/releases/download/$tag/kic-$tag-linux-amd64.tar.gz"
# tar -xvzf kic.tar.gz
# rm kic.tar.gz
# cd "$OLDPWD" || exit


echo "generating kic completion"
kic completion zsh > "$HOME/.oh-my-zsh/completions/_kic"

echo "adding k9s"
curl -fSL -o "/usr/local/bin/k9s" "https://github.com/derailed/k9s/releases/download/v0.26.3/k9s_Linux_x86_64"
sudo chmod a+x /usr/local/bin/k9s

echo "adding grafana tanka cli"
curl -fSL -o "/usr/local/bin/tk" "https://github.com/grafana/tanka/releases/download/v0.22.1/tk-linux-amd64"
chmod a+x "/usr/local/bin/tk"

echo "adding jsonnet bundler for use with Tanka"
sudo curl -Lo /usr/local/bin/jb https://github.com/jsonnet-bundler/jsonnet-bundler/releases/latest/download/jb-linux-amd64
sudo chmod a+x /usr/local/bin/jb

echo "adding argocd"
curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x /usr/local/bin/argocd

echo "creating k3d cluster"
kic cluster rebuild

echo "bilding IMDb"
kic build imdb

echo "building WebValidate"
sed -i "s/RUN dotnet test//g" /workspaces/webvalidate/Dockerfile
kic build webv

echo "deploying k3d cluster"
kic cluster deploy

# only run apt upgrade on pre-build
if [ "$CODESPACE_NAME" = "null" ]
then
    sudo apt-get update
    sudo apt-get upgrade -y
    sudo apt-get autoremove -y
    sudo apt-get clean -y
fi

echo "on-create complete"
echo "$(date +'%Y-%m-%d %H:%M:%S')    on-create complete" >> "$HOME/status"
