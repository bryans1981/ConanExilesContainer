# Docker Hub Publishing

Docker Hub publishing is complete for this repository. The image is built, tagged, pushed, and pull-verified from authenticated Docker Hub sessions.

Target image:

```text
docker.io/bryans1981/conanexilescontainer
```

Pushed tags:

```text
bryans1981/conanexilescontainer:latest
bryans1981/conanexilescontainer:<short-git-sha>
```

Semantic version tags can be added later after release versioning exists.

## Pull Verification

Pull verification passed:

```powershell
docker pull bryans1981/conanexilescontainer:latest
```

Pull must succeed before marking a publish complete.

## Preconditions

- Docker Desktop or Docker Engine is installed and working.
- You are logged in to Docker Hub with an account that can push to `bryans1981/conanexilescontainer`.
- The Docker Hub repository exists, or your Docker Hub account is allowed to create it on first push.
- Local live passwords stay in ignored env files and are not passed as build arguments.

Check login interactively if needed:

```powershell
docker login docker.io
```

## Dry Run

The publishing helper is dry-run by default. It verifies local metadata and prints the exact tags and commands it would use without building or pushing.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\dockerhub-build-push.ps1
```

## Build And Tag Locally

Use `-Build` to build and tag the image locally without pushing:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\dockerhub-build-push.ps1 -Build
```

## Push

Only use `-Push` after Docker Hub login, target repository, and user intent are confirmed.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\dockerhub-build-push.ps1 -Push
```

Optional explicit version tag:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\dockerhub-build-push.ps1 -Push -VersionTag v0.1.0
```

The script does not print credentials. It prints only the target repository and tags.

## Compose After Publish

Hosts can use the image directly instead of building locally:

```yaml
services:
  conan:
    image: bryans1981/conanexilescontainer:latest
    container_name: conan-exiles-container
    restart: unless-stopped
    env_file:
      - .env
    ports:
      - "7777:7777/udp"
      - "7778:7778/udp"
      - "27015:27015/udp"
      - "25575:25575/tcp"
    volumes:
      - ./data:/serverdata
```

Next step: set up Unraid using the Docker Hub image, map the same ports and root data volume, and set environment variables in the Unraid UI.
