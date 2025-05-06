# JavaScript PNPM Docker Build Publish

![Latest Release](https://img.shields.io/github/v/release/p6m-actions/js-pnpm-docker-build-publish?style=flat-square&label=Latest%20Release&color=blue)

## Description

A GitHub Action that builds and publishes Docker images for JavaScript applications built with PNPM. This action works seamlessly with other p6m-actions like:

- [docker-repository-login](https://github.com/p6m-actions/docker-repository-login)
- [docker-buildx-setup](https://github.com/p6m-actions/docker-buildx-setup)
- [js-pnpm-setup](https://github.com/p6m-actions/js-pnpm-setup)
- [js-pnpm-build](https://github.com/p6m-actions/js-pnpm-build)

## Usage

```yaml
- name: Build and Push Docker Images
  uses: p6m-actions/js-pnpm-docker-build-publish@v1
  with:
    affected-apps: ${{ env.AFFECTED_APPS }}
    github-token: ${{ secrets.GITHUB_TOKEN }}
    update-manifest-token: ${{ secrets.UPDATE_MANIFEST_TOKEN }}
    platform-dispatch-url: ${{ vars.PLATFORM_DISPATCH_URL }}
    registry: ${{ env.ARTIFACTORY_REGISTRY }}
```

## Inputs

| Input                   | Description                                          | Required | Default                   |
| ----------------------- | ---------------------------------------------------- | -------- | ------------------------- |
| `platforms`             | The platforms to build for (comma-separated)         | No       | `linux/amd64,linux/arm64` |
| `affected-apps`         | The affected applications to build (space-separated) | Yes      | -                         |
| `version`               | The version tag to use for the Docker images         | No       | `schedule`                |
| `github-token`          | GitHub token for authentication                      | Yes      | -                         |
| `update-manifest-token` | Token used to update image manifests                 | Yes      | -                         |
| `platform-dispatch-url` | URL to dispatch platform updates                     | Yes      | -                         |
| `registry`              | Docker registry URL                                  | Yes      | -                         |

## Outputs

| Output          | Description                            |
| --------------- | -------------------------------------- |
| `image-digests` | The digests of the built Docker images |

## Examples

### Basic Usage

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
        with:
          fetch-depth: 0

      - name: Setup PNPM and NodeJS
        uses: p6m-actions/js-pnpm-setup@v1
        with:
          node-version: 18

      - name: Build JavaScript Applications
        uses: p6m-actions/js-pnpm-build@v1
        with:
          build-command: "nx run-many --target=build --all --parallel=5 --prod --exclude docs"

      - name: Set up Docker Buildx
        uses: p6m-actions/docker-buildx-setup@v1

      - name: Login to Container Registry
        uses: p6m-actions/docker-repository-login@v1
        with:
          registry: ${{ env.ARTIFACTORY_REGISTRY }}
          username: ${{ secrets.ARTIFACTORY_USERNAME }}
          password: ${{ secrets.ARTIFACTORY_IDENTITY_TOKEN }}

      - name: Determine Affected Apps
        id: affected-apps
        run: |
          APPS=$(pnpm nx show projects --type app --exclude docs | cut -d, -f1)
          echo "AFFECTED_APPS=$(echo $APPS)" >> $GITHUB_ENV

      - name: Build and Push Docker Images
        uses: p6m-actions/js-pnpm-docker-build-publish@v1
        with:
          affected-apps: ${{ env.AFFECTED_APPS }}
          github-token: ${{ secrets.GITHUB_TOKEN }}
          update-manifest-token: ${{ secrets.UPDATE_MANIFEST_TOKEN }}
          platform-dispatch-url: ${{ vars.PLATFORM_DISPATCH_URL }}
          registry: ${{ env.ARTIFACTORY_REGISTRY }}
```

### Using Custom Platforms

```yaml
- name: Build and Push Docker Images
  uses: p6m-actions/js-pnpm-docker-build-publish@v1
  with:
    platforms: linux/amd64
    affected-apps: ${{ env.AFFECTED_APPS }}
    github-token: ${{ secrets.GITHUB_TOKEN }}
    update-manifest-token: ${{ secrets.UPDATE_MANIFEST_TOKEN }}
    platform-dispatch-url: ${{ vars.PLATFORM_DISPATCH_URL }}
    registry: ${{ env.ARTIFACTORY_REGISTRY }}
```
