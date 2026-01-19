# SkyStream Plugin Development Guide

This guide serves as the definitive reference for building, testing, packaging, and releasing extensions (plugins) for SkyStream. It consolidates information from our scraping and migration guides into a complete workflow.

## 📚 Reference Guides

Before proceeding, ensure you are familiar with the core development guides:

*   **[How to Scrape & Create a New Provider](HOW_TO_SCRAPE_NEW_PROVIDER.md)**: The technical guide on writing the JavaScript logic to scrape websites.
*   **[Kotlin to JS Migration Guide](KOTLIN_TO_JS_MIGRATION.md)**: A guide for porting existing CloudStream Kotlin providers to SkyStream's JS engine.

---

## 🛠️ Development & Local Testing

SkyStream runs on **Android, iOS, and Desktop (macOS/Windows/Linux)**. You can develop and test your plugins on *any* of these platforms using the local testing workflow.

### 1. The Local Workflow (Recommended)
You do not need a remote repository to test your code. You can inject your plugin directly into the app.

1.  **Locate the Plugins Directory**:
    Go to `skystream/assets/plugins/` in your project source.

2.  **Create Your Plugin File**:
    Create a new file named `MyProvider.js`.

3.  **Add the Code**:
    Paste your `getManifest()` and scraping logic into the file.
    *   **CRITICAL**: Ensure your `id` in `getManifest()` is unique (e.g., `com.myname.myprovider`).

4.  **Register the Asset**:
    *   **New Files**: If you just created `MyProvider.js`, you MUST stop and run `flutter run` again. Hot Restart will *not* pick up new files in assets.
    *   **Modified Files**: If the file already existed, a **Hot Restart** (`SDK 3.0+`) is usually enough, but a full restart is safer.
    *   **Enabling Debug Mode**: In `getManifest()`, append `.debug` to your ID (e.g., `com.myname.myprovider.debug`) for bypass checks.

5.  **Run the App**:
    *   `flutter run -d macos` (or windows/linux/android/ios).
    *   Go to **Settings > Extensions**.
    *   Enable **"Load plugins from assets"**.
    *   Restart the app.
    *   Your plugin should appear in the **Extensions** list with a "DEBUG" chip.

### 2. Live Reloading
*   Modify your `.js` file in `assets/plugins/`.
*   Perform a **Hot Restart** (`Search+R` or `r` in terminal).
*   The app will reload the JS engine and your new code is instantly active.

---

## 📦 Packaging for Release

When your plugin is ready for users, you must package it correctly. SkyStream supports two formats:

### A. Raw JS (Simple)
*   **Format**: Just the `.js` file (e.g., `MyProvider.js`).
*   **Pros**: Easy to host, human-readable.
*   **Cons**: No bundled icons, no extra resources.

### B. The `.sky` Package (Standard)
For a public release, bundle your plugin into a `.sky` file.

1.  **Prepare the File**:
    Rename your main script to `plugin.js`.

2.  **Zip It**:
    *   **DO NOT** zip a folder.
    *   **DO** select `plugin.js` -> Right Click -> Compress/Zip.
    *   The zip file MUST contain `plugin.js` at the **root**.

3.  **Rename**:
    Rename the file extension from `.zip` to `.sky`:
    `Archive.zip` -> `MyProvider.sky`

4.  **How it Works**:
    The app downloads the `.sky` file, extracts it, and loads `plugin.js`.
    *   *Note*: The icon is NOT loaded from the zip. You must host the `icon.png` separately and link it in your `plugins.json`.

---

## 🚀 Release & Distribution

Users install plugins via a **Repository URL**. You need to host a "Store" metadata file.

### 2. Generating the Index (`plugins.json`)
Create a JSON file that lists the actual plugins.

**Format:**
```json
[
  {
    "name": "My Provider",
    "internalName": "MyProvider",
    "url": "https://example.com/repo/MyProvider.sky",
    "icon": "https://example.com/repo/icon.png",
    "version": 1,
    "description": "Watch movies from Example.com",
    "authors": ["YourName"],
    "language": "en",
    "types": ["Movies", "TV"]
  }
]
```

### 3. Generating the Repository Manifest (`repo.json`)
SkyStream requires a "Repository Manifest" as the entry point. This file points to your `plugins.json`.

**Format:**
```json
{
  "name": "My Awesome Repository",
  "id": "com.myname.repo",
  "description": "A collection of my custom plugins",
  "manifestVersion": 1,
  "pluginLists": [
    "https://example.com/repo/plugins.json"
  ]
}
```

### 4. Hosting & Distribution
1.  Push your code to **GitHub**.
    *   Upload `.sky` files, `plugins.json`, and `repo.json`.
2.  Get the **Raw URL** of your `repo.json`.
    *   Example: `https://raw.githubusercontent.com/yourname/repo/main/repo.json`
3.  **Share this URL** with users.
    *   Users go to **Settings > Extensions > Add Repository** and paste the `repo.json` link.

### 5. Shortcode Sharing (Optional)
To make your repository easier to share, you can create a shortcode.
1.  Go to **[cutt.ly](https://cutt.ly)**.
2.  Paste your **Raw `repo.json` URL**.
3.  Create a custom alias with the prefix `sky-`.
    *   Example: `https://cutt.ly/sky-myrepo`
4.  **Share**: Users can now just type `myrepo` in the app's "Add Repository" dialog.

---

## 🔄 Updates

To update a plugin:
1.  **Increment the version** in your JS file (`getManifest`).
2.  **Increment the version** in `plugins.json`.
3.  **Repackage** the `.sky` file (if changed).
4.  Push to GitHub. Users who added your repo will see the update.

---

## ✅ Checklist Before Release
*   [ ] **Unique ID**: Confirmed `id` in `getManifest` is unique and **does not** end in `.debug`.
*   [ ] **Clean Code**: Removed debug logs (`console.log`).
*   [ ] **Headers**: Confirmed `User-Agent` and `Referer` are set to avoid 403 errors.
*   [ ] **Zip Structure**: The `.sky` file contains ONLY `plugin.js` at the root (no folders, no icons).
*   [ ] **Manifests**: Created both `repo.json` and `plugins.json`.
*   [ ] **Icon**: Hosted a high-res icon URL and added it to `plugins.json`.
*   [ ] **Distribution**: Uploaded everything to GitHub and have the raw `repo.json` URL ready to share.
