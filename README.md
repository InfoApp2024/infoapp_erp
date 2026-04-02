# infoapp

A new Flutter project.

## Web Build Recommendations

If you experience missing icons in the web build, try building with the following command to disable icon tree shaking:

```bash
flutter build web --no-tree-shake-icons
```

### Option 2: Use CanvasKit Renderer (Recommended for fidelity)
If the above doesn't work, the issue might be with the HTML renderer. 

**For Flutter 3.22+** (the `--web-renderer` flag was removed):
CanvasKit is now the default renderer. To ensure it's being used, check your `web/index.html` and verify the renderer configuration, or build with:

```bash
flutter build web
```

**For older Flutter versions** (before 3.22):
```bash
flutter build web --web-renderer canvaskit
```

*Note: CanvasKit adds about 2MB to the initial download but provides pixel-perfect rendering and fixes most icon/rendering glitches.*

### Option 3: Check Server Path (Base Href)
If you are deploying to a subfolder (e.g., `www.tusitio.com/app/`), you **must** specify the base path during build, otherwise font files (assets) won't load correctly:

```bash
flutter build web --base-href "/nombre-carpeta/"
```

### Option 4: CORS Configuration
If icons are still missing, check your browser console (F12). If you see "CORS" errors when loading `.otf` or `.ttf` files, your server needs to allow Cross-Origin requests for font files.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
