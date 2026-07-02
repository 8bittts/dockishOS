<p align="center">
  <img src="../build/dockishos.png" alt="DockishOS" width="160">
</p>

# DockishOS

**The macOS Dock shows every app on every Space. DockishOS shows what is open on this Space.**

A SwiftUI + AppKit menu-bar utility for people who use macOS Spaces heavily. Floating, per-display app bar. Scroll over the bar to switch Spaces. Drag `.app` bundles to pin them. macOS 14+, Apple Silicon, signed and notarized.

<p align="center">
  <a href="https://github.com/8bittts/dockishOS/releases/latest">
    <strong>Download the latest DMG →</strong>
  </a>
</p>

<p align="center">
  <img src="../public/dockishos-bar-preview.png" alt="DockishOS showing a floating current-Space app bar with app chips" width="100%">
</p>

## Why DockishOS

- **Current-Space only.** See and switch the windows that matter right now, not every app on every desktop.
- **Scroll-to-switch.** Scroll over the bar to move between Spaces without opening Mission Control.
- **Drag to pin.** Drop `.app` bundles or right-click windows and launcher results to keep important apps close.
- **Stays out of the way.** Menu-bar accessory app. No Dock icon. No background polling fanfare.

## Install

Download the latest signed & notarized DMG, then drag DockishOS to `/Applications`:

```bash
open https://github.com/8bittts/dockishOS/releases/latest
```

Or install with [Homebrew](https://brew.sh) — the repo doubles as a Cask tap:

```bash
# One-shot install of the latest release:
brew install --cask https://raw.githubusercontent.com/8bittts/dockishOS/main/Casks/dockishos.rb

# Or tap for ongoing `brew upgrade`:
brew tap 8bittts/dockishos https://github.com/8bittts/dockishOS
brew install --cask 8bittts/dockishos/dockishos
```

## Auto-update

Built-in via [Sparkle](https://sparkle-project.org/) with an EdDSA-signed appcast. New releases reach existing installs automatically.

## Source

[github.com/8bittts/dockishOS](https://github.com/8bittts/dockishOS) — MIT licensed.
