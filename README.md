# JavaScript PNPM Docker Build Publish

![Latest Release](https://img.shields.io/github/v/release/p6m-actions/js-pnpm-docker-build-publish?style=flat-square&label=Latest%20Release&color=blue)

## Description

A simple GitHub Action that builds and publishes a Docker image for a JavaScript application. This action is a thin wrapper around `docker buildx build` that automatically handles tagging with package version and retrieval of the image digest.

This action works seamlessly with other p6m-actions like:

- [docker-repository-login](https://github.com/p6m-actions/docker-repository-login)
- [docker-buildx-setup](https://github.com/p6m-actions/docker-buildx-setup)
- [platform-application-manifest-dispatch](https://github.com/p6m-actions/platform-application-manifest-dispatch)

## Usage

```yaml
- name: Build and Push Docker Image
  uses: p6m-actions/js-pnpm-docker-build-publish@v1
  with:
    registry: ${{ env.ARTIFACTORY_REGISTRY }}
```

## Inputs

| Input         | Description                                                | Required | Default                   |
| ------------- | ---------------------------------------------------------- | -------- | ------------------------- |
| `platforms`   | The platforms to build for (comma-separated)               | No       | `linux/amd64,linux/arm64` |
| `app-name`    | The name of the application to build                       | No       | Repository name           |
| `version`     | The version to use for the Docker image                    | No       | From package.json         |
| `tag-latest`  | Whether to also tag the image as 'latest'                  | No       | `true`                    |
| `dockerfile`  | Path to the Dockerfile                                     | No       | `Dockerfile`              |
| `context`     | Docker build context                                       | No       | `.`                       |
| `registry`    | Docker registry URL                                        | Yes      | -                         |

## Outputs

| Output         | Description                                |
| -------------- | ------------------------------------------ |
| `image-digest` | The digest of the built Docker image       |
| `image-name`   | The full name of the built image with tag  |
| `version`      | The version used for tagging the image     |

## Key Features

- **Automatic Version Tagging**: Extracts version from package.json and uses it to tag the image
- **Multi-platform Support**: Builds for multiple platforms in one command
- **Latest Tag**: Optionally tags the image as 'latest' in addition to the version tag
- **Simple Integration**: Works with minimal configuration in most JavaScript projects

## Examples

### Basic Usage

The simplest way to use this action:

```yaml
name: Build and Deploy

on:
  push:
    branches: [main]

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Code
        uses: actions/checkout@v3

      - name: Set up Docker Buildx
        uses: p6m-actions/docker-buildx-setup@v1

      - name: Login to Container Registry
        uses: p6m-actions/docker-repository-login@v1
        with:
          registry: ${{ env.ARTIFACTORY_REGISTRY }}
          username: ${{ secrets.ARTIFACTORY_USERNAME }}
          password: ${{ secrets.ARTIFACTORY_IDENTITY_TOKEN }}

      - name: Build and Push Docker Image
        id: build-push
        uses: p6m-actions/js-pnpm-docker-build-publish@v1
        with:
          registry: ${{ env.ARTIFACTORY_REGISTRY }}
```

### With Custom Version

If you want to specify a version instead of extracting it from package.json:

```yaml
- name: Build and Push Docker Image
  id: build-push
  uses: p6m-actions/js-pnpm-docker-build-publish@v1
  with:
    version: "2.3.1"
    registry: ${{ env.ARTIFACTORY_REGISTRY }}
```

### With Custom Configuration and No Latest Tag

For more specific needs:

```yaml
- name: Build and Push Docker Image
  id: build-push
  uses: p6m-actions/js-pnpm-docker-build-publish@v1
  with:
    app-name: "my-custom-app-name"
    platforms: linux/amd64
    tag-latest: "false"
    dockerfile: "./docker/Dockerfile.prod"
    context: "./dist"
    registry: ${{ env.ARTIFACTORY_REGISTRY }}
```

### With Manifest Dispatch

You can use this action with the platform-application-manifest-dispatch action to update your application manifests:

```yaml
- name: Build and Push Docker Image
  id: build-push
  uses: p6m-actions/js-pnpm-docker-build-publish@v1
  with:
    registry: ${{ env.ARTIFACTORY_REGISTRY }}

- name: Update Application Manifest
  if: steps.build-push.outputs.image-digest != ''
  uses: p6m-actions/platform-application-manifest-dispatch@v1
  with:
    repository: ${{ github.repository }}
    image-name: "fe-$(basename ${GITHUB_REPOSITORY})"
    environment: "dev"
    digest: ${{ steps.build-push.outputs.image-digest }}
    update-manifest-token: ${{ secrets.UPDATE_MANIFEST_TOKEN }}
    platform-dispatch-url: ${{ vars.PLATFORM_DISPATCH_URL }}
```

## Behind the Scenes

This action essentially performs the following steps:

1. Determines the application name (from input or repository name)
2. Extracts the version from package.json or uses the provided version
3. Constructs the full image name with registry, app name, and version
4. Runs `docker buildx build` with the specified platforms and tags
5. Extracts the image digest from the pushed image
6. Returns the digest, image name, and version as outputs

The simplified command it runs (when also tagging as latest) is similar to:

```bash
docker buildx build --platform linux/amd64,linux/arm64 \
  -t registry/app-name:1.2.3 \
  -t registry/app-name:latest \
  -f Dockerfile --push .
```