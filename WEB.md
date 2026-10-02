# Snake Stages on iPhone

## Install a published build

1. Open the game URL in Safari and let the first download finish.
2. Wait for **Offline ready** at the bottom.
3. Tap Safari's **Share** button, then **Add to Home Screen**.
4. Launch Snake Stages from its icon. Tap Play, choose a mode, and tap Go.

Use the large direction buttons or swipe on the board. Two quick turns can be buffered; reversing is blocked. Each phone run begins with an inspectable board before Go starts movement. Switching apps or resizing pauses movement; resuming is deliberate. Shield recovery accepts a safe direction from either touch control. Campaign, Endless, and Adventure share the desktop rules.

Your iPhone's records are saved locally. Windows scores do not automatically transfer or sync. Removing website data or browser storage eviction can remove offline files and progress. PWA updates show **Update ready · Reload** and wait for your choice, rather than interrupting a run. Old game caches are removed only within this game's scope; update cleanup does not delete player saves.

## Build

Requires Godot **4.7.2 standard**, Node.js, and Windows PowerShell. From the project:

```powershell
.\tools\Build-Web.ps1 -GodotExecutable 'C:\path\to\Godot_console.exe'
```

The build script downloads the official single-threaded web templates, imports resources, exports the project, and prepares the manifest and versioned offline worker. It writes the website to `.build/web/`. Exporting and tests use disposable APPDATA profiles rather than the real player profile.

The preset uses the Compatibility renderer, disables threads and extensions, and exports a custom responsive HTML shell. The shell respects safe-area insets and caps rendering density at 2x. Browser builds use Godot's included font rather than depending on Windows fonts. The phone direction arrows are vector shapes.

Serve the export over HTTP for local testing, or HTTPS for installation and offline support. Opening `index.html` as a local file will not run the game. The runtime is about 40 MB uncompressed; the game pack is under 100 KB. The initial download is larger than subsequent cached launches.

## Publish to GitHub Pages

The intended repository is `https://github.com/amdelaney95-ux/Snakegame`.

The included `.github/workflows/pages.yml` builds and tests the game on every push to `main`, exports with Godot 4.7.2, and publishes the PWA.

1. In **Settings → Pages**, select **GitHub Actions** as the source.
2. Push the Godot source and workflow to `main`.
3. Wait for **Build and publish Snake Stages** in the Actions tab to succeed.
4. Open `https://amdelaney95-ux.github.io/Snakegame/` in Safari.

No backend, API keys, special cross-origin headers, or App Store submission are needed. Future source updates automatically rebuild the website and its versioned offline cache. Players choose when to reload an update.

The prepared local `docs/` export remains available for manual hosting, but the automated deployment builds directly from source and does not need exported binaries committed to Git.

## Checks

`tools/Check-Project.ps1` runs the rules, full Campaign, Endless, Adventure, and phone suites with isolated saves. Adventure tests include real full-food Gold runs through every maze. Phone tests cover taps, two-finger buffering, continuous swipes, reversal rejection, shield recovery, background pause, ready-screen time, and portrait/landscape geometry.

Browser verification includes startup, course selection, the ready screen, visible direction controls, browser-record retention across an update, and loading while the local server is unavailable. This is not physical iPhone testing.

Before considering the phone release fully device-verified, check on your iPhone:

- All four touch directions, rapid corners, and continuous swipes.
- Shield recovery and the smallest Adventure corridors.
- Sound after tapping; mute; switching apps and returning.
- Portrait, landscape, Safari toolbar changes, and the home indicator/notch.
- Saved scores after closing and reopening the installed app.
- Offline launch after the first complete download.
- An installed update that preserves progress.
