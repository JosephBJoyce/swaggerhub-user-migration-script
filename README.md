# SwaggerHub User Migration

This is a script that will migrate users (and their role) from one SwaggerHub organization to another.

# How to Run the Script

## 1. Save the Script to a File

Open a terminal and create a new file:

```bash
nano migrate_swaggerhub_users.sh
```

Paste the script into the editor, then press `CTRL + X`, `Y`, and `Enter` to save.

---

## 2. Make the Script Executable

Grant execute permissions:

```bash
chmod +x migrate_swaggerhub_users.sh
```

---

## 3. Install `jq` (If Not Installed)

`jq` is needed to process JSON responses. Install it using:

- **Ubuntu/Debian**:
  ```bash
  sudo apt-get install jq
  ```
- **Mac (Homebrew)**:
  ```bash
  brew install jq
  ```
- **Windows** (WSL or Git Bash):\
  Download from [jq official site](https://stedolan.github.io/jq/download/).

---

## 4. Set API Keys and Organization Names

Edit the script to include your actual API keys and organization names:

```bash
nano migrate_swaggerhub_users.sh
```

Replace these placeholders:

- `SOURCE_ORG="your_source_org"`
- `TARGET_ORG="your_target_org"`
- `SOURCE_API_KEY="your_source_api_key"`
- `TARGET_API_KEY="your_target_api_key"`

---

## 5. Run the Script

Execute the script with:

```bash
./migrate_swaggerhub_users.sh
```

---

## 6. Verify the Migration

Check your **target organization** on SwaggerHub to confirm that users were successfully added.

---

## Troubleshooting

- If you see `command not found: jq`, install `jq` using the instructions above.
- If you get an authentication error, verify that your **API keys** are correct.
- If the script fails, run it in debug mode for more details:
  ```bash
  bash -x ./migrate_swaggerhub_users.sh
  ```
  This will show each command as it runs, helping to diagnose issues.

