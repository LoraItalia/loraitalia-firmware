Below is a step-by-step description of the workflow defined in your YAML file. Use it as a manual or reference to understand what the GitHub Actions pipeline does at each stage:

---

## Overview

This GitHub Actions workflow is designed to:

1. Validate a specific tag format (e.g., `v2.5.19.d5cd6f8`).
2. Check out a repository at that tag, fetch and apply associated patches.
3. Build firmware for multiple board types using PlatformIO.
4. Upload the resulting firmware files both to an FTP server and as GitHub Actions artifacts.

You can manually trigger the workflow via a `workflow_dispatch` event and supply the following inputs:

- **tag** (required): The firmware tag to build (e.g., `v2.5.19.d5cd6f8`).  
- **ftpTarget** (required, default `/`): The directory on the FTP server where the firmware artifacts will be placed.

---

## Inputs

1. **tag**  
   - **description**: The firmware version tag to build (must match the format `v<major>.<minor>.<build>.<commit>`).  
   - **example**: `v2.5.19.d5cd6f8`

2. **ftpTarget**  
   - **description**: Directory path on the FTP server where the built firmware will be uploaded.  
   - **default**: `/`

---

## Job: build

### 1. Validate Tag

```yaml
- name: Validate tag
  run: |
    validate_tag() {
      local tag="$1"
      if [[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9][0-9]+\.([a-z0-9]{7})$ ]]; then
        return 0
      else
        return 1
      fi
    }    
    if ! validate_tag "${{ inputs.tag }}"; then
      echo "Errore: il tag '${{ inputs.tag }}' non è valido. Deve rispettare il formato v2.5.19.d5cd6f8."
      exit 1
    else
      echo "Il tag '${{ inputs.tag }}' è valido."
    fi
```

- **Purpose**:  
  Ensures the provided `tag` matches a specific version format: `v<major>.<minor>.<build>.<git-sha>`.  
  - Example of a valid tag: `v2.5.19.d5cd6f8`  
  - If the format is incorrect, the workflow fails immediately.

---

### 2. Checkout Repository

```yaml
- name: Checkout Repository
  uses: actions/checkout@v4
  with:
    fetch-depth: 0
```

- **Purpose**:  
  Checks out the code from the repository so it can be built, patched, and processed. Using `fetch-depth: 0` ensures that all commits and tags are fetched.

---

### 3. Configure Git

```yaml
- name: Configure Git
  run: |
    git config --global user.name "GitHub Actions"
    git config --global user.email "actions@github.com"
```

- **Purpose**:  
  Sets up a global Git identity (name and email) for subsequent Git operations. This is often useful when applying patches or pushing tags/commits (if that were part of the workflow).

---

### 4. Fetch Tags from Upstream

```yaml
- name: Fetch Tags from Upstream
  run: |
    git remote add upstream https://github.com/meshtastic/firmware.git
    git fetch upstream
```

- **Purpose**:  
  Adds a remote called `upstream` (in this case, the original Meshtastic repository).  
  Fetches all branches and tags from that remote for reference or checkout.

---

### 5. Checkout Code for Target Tag

```yaml
- name: Checkout Code for Target Tag
  run: |
    git checkout "tags/${{ inputs.tag }}"
```

- **Purpose**:  
  Checks out the repository at the specific tag that was validated in step 1.

---

### 6. Checkout Patch Files

```yaml
- name: Checkout Patch Files
  run: |
    git fetch origin "refs/tags/patches-${{ inputs.tag }}:refs/tags/patches-${{ inputs.tag }}"
    git checkout "patches-${{ inputs.tag }}" -- *.patch
```

- **Purpose**:  
  Fetches and checks out patch files stored in a special tag named `patches-<yourTag>`.  
  This step assumes you keep your patches in a separate tag that follows this naming pattern.  
  It then checks out any `.patch` files from that tag.

---

### 7. Apply Patches

```yaml
- name: Apply Patches
  run: |
    for patch in *.patch; do
      if git apply "$patch"; then
        echo "Patch $patch applicato con successo."
      else
        echo "Errore: il patch $patch non è applicabile."
        exit 1
      fi
    done
```

- **Purpose**:  
  Applies each `.patch` file found in the current working directory.  
  If any patch fails to apply, the workflow exits.

---

### 8. Cache Dependencies

```yaml
- uses: actions/cache@v4
  with:
    path: |
      ~/.cache/pip
      ~/.platformio/.cache
    key: ${{ runner.os }}-pio
```

- **Purpose**:  
  Speeds up the workflow by caching Python packages (`~/.cache/pip`) and PlatformIO’s own cache (`~/.platformio/.cache`).  
  Subsequent workflow runs can leverage the cached dependencies, reducing build times.

---

### 9. Setup Python

```yaml
- uses: actions/setup-python@v5
  with:
    python-version: '3.11'
```

- **Purpose**:  
  Ensures the build environment has Python 3.11 installed, which is required for PlatformIO and other Python-based tools.

---

### 10. Read Version from File

```yaml
- name: Read version from file
  id: get_version
  run: |
    version=$(grep -oP '(?<=major = )\d+' version.properties).$(grep -oP '(?<=minor = )\d+' version.properties).$(grep -oP '(?<=build = )\d+' version.properties)
    commit_hash=$(git rev-parse --short HEAD)
    echo "VERSION_TAG=$version-$commit_hash" >> $GITHUB_ENV
```

- **Purpose**:  
  Reads version components (`major`, `minor`, `build`) from `version.properties` using `grep` with lookbehind regex.  
  Retrieves the short commit hash (e.g., `1234abc`).  
  Creates an environment variable `VERSION_TAG` (e.g., `2.5.19-1234abc`) that will be used to name the firmware files.

---

### 11. Install PlatformIO Core

```yaml
- name: Install PlatformIO Core
  run: pip install --upgrade platformio
```

- **Purpose**:  
  Installs (or upgrades) the PlatformIO CLI on the runner. This is required to build the firmware.

---

### 12. Build PlatformIO Project

```yaml
- name: Build PlatformIO Project
  run: pio run
```

- **Purpose**:  
  Invokes PlatformIO’s default build command (`pio run`) to compile the firmware for all defined environments in your `platformio.ini`.

---

### 13. Create folder with builds

```yaml
- name: Create folder with builds
  run: |
    mkdir artifacts
    mkdir artifacts/firmware-${{ env.VERSION_TAG }}
    mkdir artifacts/firmware-${{ env.VERSION_TAG }}/tbeam
    mkdir artifacts/firmware-${{ env.VERSION_TAG }}/rak4631
    mkdir artifacts/firmware-${{ env.VERSION_TAG }}/heltec-v3
    mkdir artifacts/firmware-${{ env.VERSION_TAG }}/tlora-v2-1-1_6
    mkdir artifacts/firmware-${{ env.VERSION_TAG }}/t-echo
    mkdir artifacts/firmware-${{ env.VERSION_TAG }}/heltec-mesh-node-t114
    cp .pio/build/tbeam/firmware.bin artifacts/firmware-${{ env.VERSION_TAG }}/tbeam/firmware.${{ env.VERSION_TAG }}.update.bin
    cp .pio/build/tbeam/firmware.factory.bin artifacts/firmware-${{ env.VERSION_TAG }}/tbeam/firmware.${{ env.VERSION_TAG }}.factory.bin
    cp .pio/build/rak4631/firmware.uf2 artifacts/firmware-${{ env.VERSION_TAG }}/rak4631/firmware.${{ env.VERSION_TAG }}.uf2
    cp .pio/build/rak4631/firmware.zip artifacts/firmware-${{ env.VERSION_TAG }}/rak4631/firmware.${{ env.VERSION_TAG }}.zip
    cp .pio/build/tlora-v2-1-1_6/firmware.bin artifacts/firmware-${{ env.VERSION_TAG }}/tlora-v2-1-1_6/firmware.${{ env.VERSION_TAG }}.update.bin
    cp .pio/build/tlora-v2-1-1_6/firmware.factory.bin artifacts/firmware-${{ env.VERSION_TAG }}/tlora-v2-1-1_6/firmware.${{ env.VERSION_TAG }}.factory.bin
    cp .pio/build/heltec-v3/firmware.bin artifacts/firmware-${{ env.VERSION_TAG }}/heltec-v3/firmware.${{ env.VERSION_TAG }}.update.bin
    cp .pio/build/heltec-v3/firmware.factory.bin artifacts/firmware-${{ env.VERSION_TAG }}/heltec-v3/firmware.${{ env.VERSION_TAG }}.factory.bin
    cp .pio/build/t-echo/firmware.uf2 artifacts/firmware-${{ env.VERSION_TAG }}/t-echo/firmware.${{ env.VERSION_TAG }}.uf2
    cp .pio/build/t-echo/firmware.zip artifacts/firmware-${{ env.VERSION_TAG }}/t-echo/firmware.${{ env.VERSION_TAG }}.zip
    cp .pio/build/heltec-mesh-node-t114/firmware.uf2 artifacts/firmware-${{ env.VERSION_TAG }}/heltec-mesh-node-t114/firmware.${{ env.VERSION_TAG }}.uf2
    cp .pio/build/heltec-mesh-node-t114/firmware.zip artifacts/firmware-${{ env.VERSION_TAG }}/heltec-mesh-node-t114/firmware.${{ env.VERSION_TAG }}.zip
```

- **Purpose**:  
  Creates an `artifacts` directory structure for each board type (e.g., `tbeam`, `rak4631`, `heltec-v3`, etc.) and copies the compiled firmware files from the `.pio/build/<board>` directory into these folders.  
- **Note**:  
  Each firmware file is renamed to include the environment variable `${{ env.VERSION_TAG }}` so they are clearly versioned.

---

### 14. Upload FTP

```yaml
- name: Upload FTP
  uses: SamKirkland/FTP-Deploy-Action@v4.3.5
  with:
    server: ${{ secrets.FTP_HOST }}
    username: ${{ secrets.FTP_USERNAME }}
    password: ${{ secrets.FTP_PASSWORD }}
    local-dir: "artifacts/"
    server-dir: "${{ inputs.ftpTarget }}"
```

- **Purpose**:  
  Uses the [FTP-Deploy-Action](https://github.com/SamKirkland/FTP-Deploy-Action) to upload the `artifacts` directory to an FTP server.  
  - **server**: FTP hostname (stored as a GitHub secret).  
  - **username**, **password**: FTP credentials (also stored as GitHub secrets).  
  - **local-dir**: The directory on the GitHub runner that contains the build artifacts (`artifacts/`).  
  - **server-dir**: The path on the server to which files will be uploaded (specified by `ftpTarget` input).

---

### 15. Upload Artifacts (GitHub)

```yaml
- name: Upload Artifacts
  uses: actions/upload-artifact@v4
  with:
    name: Releases
    path: |
      artifacts/*
```

- **Purpose**:  
  Archives the entire `artifacts` directory for the current workflow run. This makes your build output available directly on GitHub under the “Actions” tab for later download or reference.

---

## Typical Workflow Usage

1. **Trigger the workflow**:  
   Go to the **Actions** tab in your GitHub repository, select this workflow (named “PlatformIO CI”), then click **Run workflow**.  
2. **Enter inputs**:
   - **Tag**: e.g. `v2.5.19.d5cd6f8`  
   - **ftpTarget**: e.g. `/firmware/`  
3. **Run**:  
   The GitHub Action will start, validate the tag, check out your code at that tag, apply patches, build the firmware, and upload artifacts.

---

## Important Notes

- **Tag Format**:  
  The script requires the tag format to match `^v[0-9]+\.[0-9]+\.[0-9][0-9]+\.([a-z0-9]{7})$`. Modify the regex in the “Validate Tag” step if you need to support a different format.
- **Patch Handling**:  
  Patches are assumed to exist in a special tag named `patches-<yourTag>`. Adjust the “Checkout Patch Files” step if your patches are stored differently.
- **Version Tag in Firmware Filenames**:  
  A second version tag is constructed from `version.properties` plus a short commit hash. That string is appended to each firmware file’s name (e.g. `firmware.2.5.19-1234abc.update.bin`). If you want your final output to strictly match your input tag, you can alter this logic in the “Read version from file” step.
- **FTP Server Credentials**:  
  Make sure you have configured the following secrets in your repository’s settings to use the FTP upload step:
  - `FTP_HOST`
  - `FTP_USERNAME`
  - `FTP_PASSWORD`
- **PlatformIO Environments**:  
  This workflow expects pre-defined [env] sections in `platformio.ini` (e.g., `[env:tbeam]`, `[env:rak4631]`, etc.). Ensure those match the references in the copy commands under “Create folder with builds.”

---

### Further Customization

You can easily modify or extend the workflow to:

- Build only specific PlatformIO environments (e.g., by specifying `pio run -e <envName>`).
- Push the built firmware to GitHub Releases instead of (or in addition to) the FTP server.
- Automate version bumping by combining this workflow with a release workflow.

This manual should help you understand each step’s purpose and how to customize the workflow to your specific needs.