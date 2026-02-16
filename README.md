# JavaScript PNPM Docker Build Publish

![Latest Release](https://img.shields.io/github/v/release/p6m-actions/js-pnpm-docker-build-publish?style=flat-square&label=Latest%20Release&color=blue)

## Description

A simple GitHub Action that builds and publishes a Docker image for a JavaScript application. This action automatically handles tagging with package version and retrieval of the image digest, simplifying the Docker build and publish process in your workflows.

This action works seamlessly with other p6m-actions like:

- [docker-repository-login](https://github.com/p6m-actions/docker-repository-login)
- [docker-buildx-setup](https://github.com/p6m-actions/docker-buildx-setup)
- [js-pnpm-setup](https://github.com/p6m-actions/js-pnpm-setup)
- [js-pnpm-build](https://github.com/p6m-actions/js-pnpm-build)
- [platform-application-manifest-dispatch](https://github.com/p6m-actions/platform-application-manifest-dispatch)

## Usage

```yaml
- name: Build and Push Docker Image
  uses: p6m-actions/js-pnpm-docker-build-publish@v1
  with:
    registry: ${{ env.ARTIFACTORY_REGISTRY }}
```

## Inputs

| Input          | Description                                                | Required | Default                   |
| -------------- | ---------------------------------------------------------- | -------- | ------------------------- |
| `project-path` | Relative path to the project directory containing package.json (must not contain '..' or be absolute) | No | `.` |
| `platforms`    | The platforms to build for (comma-separated)               | No       | `linux/amd64,linux/arm64` |
| `image-name`   | The name for the Docker image                              | No       | Repository name           |
| `version`      | The version to use for the Docker image                    | No       | From package.json         |
| `tag-latest`   | Whether to also tag the image as 'latest'                  | No       | `true`                    |
| `dockerfile`   | Path to the Dockerfile                                     | No       | `Dockerfile`              |
| `context`      | Docker build context                                       | No       | `.`                       |
| `registry`     | Docker registry URL                                        | Yes      | -                         |

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
    image-name: "my-custom-image-name"
    platforms: linux/amd64
    tag-latest: "false"
    dockerfile: "./docker/Dockerfile.prod"
    context: "./dist"
    registry: ${{ env.ARTIFACTORY_REGISTRY }}
```

### Project in a Subdirectory

For repositories where the project is not at the root. The `project-path` specifies where to find `package.json` for version extraction:

```yaml
- name: Setup PNPM
  uses: p6m-actions/js-pnpm-setup@v1
  with:
    project-path: "packages/frontend"

- name: Build Application
  uses: p6m-actions/js-pnpm-build@v1
  with:
    project-path: "packages/frontend"

- name: Build and Push Docker Image
  uses: p6m-actions/js-pnpm-docker-build-publish@v1
  with:
    project-path: "packages/frontend"
    context: "packages/frontend"
    dockerfile: "packages/frontend/Dockerfile"
    registry: ${{ env.ARTIFACTORY_REGISTRY }}
```

> **Note:** The `project-path` is used for version extraction from `package.json`. You typically want `context` to match `project-path`, and `dockerfile` to point to the Dockerfile within that directory.

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

### Complete CI/CD Workflow Example

Here's a comprehensive example showing a full CI/CD workflow with all p6m-actions:

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
          
      # Set up Node.js and PNPM with caching
      - name: Setup Node.js and PNPM
        uses: p6m-actions/js-pnpm-setup@v1
        with:
          node-version: 18
          install-dependencies: true
          
      # Build the application with proper linting
      - name: Build JavaScript Application
        id: build-js
        uses: p6m-actions/js-pnpm-build@v1
        with:
          run-lint: true
          build-args: "--all --parallel=5 --prod --exclude docs"
        
      # Set up Docker Buildx for multi-architecture builds
      - name: Set up Docker Buildx
        uses: p6m-actions/docker-buildx-setup@v1

      # Log in to container registry
      - name: Login to Container Registry
        uses: p6m-actions/docker-repository-login@v1
        with:
          registry: ${{ env.ARTIFACTORY_REGISTRY }}
          username: ${{ secrets.ARTIFACTORY_USERNAME }}
          password: ${{ secrets.ARTIFACTORY_IDENTITY_TOKEN }}

      # Build and push Docker image with version from package.json
      - name: Build and Push Docker Image
        id: build-push
        uses: p6m-actions/js-pnpm-docker-build-publish@v1
        with:
          registry: ${{ env.ARTIFACTORY_REGISTRY }}
          
      # Update application manifest with the new image digest
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

## How It Works

This action performs the following steps:

1. Determines the image name (from input or repository name)
2. Extracts the version from package.json or uses the provided version
3. Constructs the full image name with registry, image name, and version
4. Builds and pushes the Docker image with the appropriate tags
5. Extracts the image digest from the pushed image
6. Returns the digest, image name, and version as outputs

By using this action instead of directly calling Docker commands, you get:

- Automatic version extraction from package.json
- Proper handling of multiple platforms
- Simple configuration with sensible defaults
- Reliable digest extraction for use with manifest updates
- Better workflow portability and maintainability