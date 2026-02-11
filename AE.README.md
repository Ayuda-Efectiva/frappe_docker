IMPORTANT!

- our files are su-prefixed with AE.
- our branch is `ae-main`
- Upstream must be official `frappe-docker` repo.

# LOCAL


Clone repo to local:

```bash
git clone https://github.com/Ayuda-Efectiva/frappe_docker_ae frappe_docker_ae
cd frappe_docker_ae

# Create symlink folder `.devcontainer` pointed to our `./devcontainer.AE` folder:
ln -s devcontainer.AE .devcontainer
```

WIP

... Devpods!!


## Create bench

WIP

### Install apps

WIP

### Create site

WIP


----


# PORTAINER: STAGING

`AE.portainer.stack.staging.frappe-staging.yml`
`AE.portainer.stack.staging.mariadb.yml`
.env saved within Vaultwarden.

WIP

# PORTAINER: STAGING

`AE.portainer.stack.prod.frappe-prod.yml`
`AE.portainer.stack.prod.mariadb.yml`
.env saved within Vaultwarden.

WIP


----



# Update this repo


```bash
git fetch upstream

actualizar main
actualizar ae-main

```











# STAGING & PRODUCTION

WIP

## CUSTOMIZE AND DEPLOY

[Repos](http://localhost:5000/v2/_catalog)
[Repo `frappe-ae` tags](http://localhost:5000/v2/frappe-ae/tags/list)

### Get a PAT (Personal Access Token) from Github

- "Profile": "Settings": "Developer Settings": "Personal access tokens": "Tokens"
- Set permissions for: "repo" and "write:packages"

Save to .env in this repo:

```env
AE_VERSION=37

AE_BRANCH=develop
# AE_BRANCH=version-15
# AE_BRANCH=feat-impact-share

# Do not touch!
AE_IMAGE_VERSION=frappe-ae:$AE_BRANCH-$AE_VERSION
# User and github PAT separated by :
GITHUB_USER_AND_PAT=<USERNAME>:<GET PAT FROM GITHUB/BITWARDEN>
```

### HOW TO DEPLOY

```bash
# 1. Forward needed ports (Registry and Portainer)
# ssh -L 5000:127.0.0.1:5000 -L 9999:127.0.0.1:9999 root@ae01.ayudaefectiva.org
# Anyone: Staging
ssh -L 9999:127.0.0.1:9999 -L 5000:127.0.0.1:5000 root@srv02.ayudaefectiva.org
# Anyone: Prod
ssh -L 9999:127.0.0.1:9999 -L 5000:127.0.0.1:5000 root@ae05.ayudaefectiva.org
# Joan
ssh -i /home/joan/.ssh/id_rsa -L 9999:127.0.0.1:9999 -L 5000:127.0.0.1:5000 joan@ae05.ayudaefectiva.org
```

#### Increase version number

```ssh
vi .env
```

#### Create image

IMPORTANT! If apps have new requirements (python or node) add "--no-cache" to below command

```ssh
# --tag=localhost:5000/$AE_IMAGE_VERSION
source .env && docker build --progress=plain --build-arg=GITHUB_USER_AND_PAT=$GITHUB_USER_AND_PAT --build-arg=AE_BRANCH=$AE_BRANCH --build-arg=AE_IMAGE_VERSION=$AE_IMAGE_VERSION --tag=10.200.200.2:5000/frappe-ae:$AE_BRANCH-$AE_VERSION --file=images/custom/AE.Containerfile . && docker push 10.200.200.2:5000/frappe-ae:$AE_BRANCH-$AE_VERSION
```

#### Rename image

```ssh
# Rename image: deploy to staging + run tests + if tests are ok => deploy to prod
docker image tag localhost:5000/$AE_IMAGE_VERSION localhost:5000/frappe-ae:merged-$AE_VERSION && docker image rm localhost:5000/$AE_IMAGE_VERSION
```

#### Push to local registry

```ssh
docker push localhost:5000/frappe-ae:merged-$AE_VERSION
# Below to keep source branch within image name (testing branches in staging, mainly)
docker push localhost:5000/$AE_IMAGE_VERSION
# http://127.0.0.1:9999/#!/1/docker/stacks/frappe-staging?id=7&type=1&regular=true
```

#### Copy version printed by

```ssh
echo $AE_IMAGE_VERSION
```

Now, go to [Portainer](http://127.0.0.1:9999) > primary environment > stacks > frappe-staging > editor > DFP_IMAGE_VERSION > paste new image version > "Update the stack"

## CUSTOMIZE .env

Copy `example.env` to `.env`, and then add below vars to `.env` beginning:

```ini
# AE_BRANCH=version-15
AE_BRANCH=develop
AE_VERSION=1.0.26
# Do not touch!
AE_IMAGE_VERSION=frappe-ae:$AE_BRANCH-$AE_VERSION
# User and github PAT separated by : to retrieve our apps from GitHub
GITHUB_USER_AND_PAT=user:ghp_...
```

## CLEAN DOCKER TASKS (CACHES)

```bash
docker system df
# Eliminará todos los contenedores detenidos, todas las redes no utilizadas, y todas las imágenes colgadas (imágenes sin etiquetas). Si además quieres eliminar imágenes no utilizadas (no solo las colgantes), puedes añadir la opción -a.
docker system prune
# Eliminar volúmenes no utilizados
docker volume prune
```

## CLEAN REGISTRY

```bash
# Check repositories list
curl -s "http://localhost:5000/v2/_catalog"
# Check tags list for "frappe-ae" repository
curl -s "http://localhost:5000/v2/frappe-ae/tags/list" | jq -r '.tags[]' | sort -V
curl http://localhost:5000/v2/frappe-ae/tags/list

# --------------------------

# Using skopeo
sudo apt install skopeo
# Tags
skopeo list-tags --tls-verify=false docker://localhost:5000/frappe-ae
skopeo list-tags --tls-verify=false docker://localhost:5000/ae-caddy
# Inspect tag
skopeo inspect --tls-verify=false docker://localhost:5000/frappe-ae:version-14-7
# Mark tag for deletion with garbage collector
skopeo delete --tls-verify=false docker://localhost:5000/frappe-ae:version-14-12
skopeo delete --tls-verify=false docker://localhost:5000/frappe-ae:develop-15
# Within container registry ash:
/bin/registry garbage-collect -m /etc/docker/registry/config.yml

# Check docker by folder size
cd /var/lib/docker && du -sh */ | sort -rh
# Do docker system prune
docker system prune
cd /var/lib/docker && du -sh */ | sort -rh

# --------------------------

# Using ash within registry container

# Execute deletion: Portainer > contenedor > ash:

# There are cleaner ways of doing this with the HTTP/REST API but you can execute a controlled deletion of old tags (>10days) with this command:
# Check
find /var/lib/registry/docker/registry/v2/repositories/*/_manifests/tags -type d -mtime +10 -maxdepth 1
# Execute
find /var/lib/registry/docker/registry/v2/repositories/*/_manifests/tags -type d -mtime +10 -maxdepth 1 -exec rm -rf {} \;
/bin/registry garbage-collect -m /etc/docker/registry/config.yml

```

# UPDATE DATABASE FROM PROD TO LOCAL

```bash
# BACKUP: PROD: Portainer > stacks > frappe-prod > frappe-prod_backend > terminal
bench backup --with-files
# RESTORE: LOCAL (jaime)
cd /home/james/WWW/developmentforpeople/aedocker/development/frappe-bench
scp root@ae05.ayudaefectiva.org:/root/ae-data/benches/frappe-prod/sites/prod.ayudaefectiva.org/private/backups/* ./
# VSCODE: devcontainer: terminal
cd frappe-bench
bench --site ayudaefectiva.localhost restore --with-private-files 20240613_135235-prod_ayudaefectiva_org-private-files.tar --with-public-files 20240613_135235-prod_ayudaefectiva_org-files.tar 20240613_135235-prod_ayudaefectiva_org-database.sql.gz

```
