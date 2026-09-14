cask "dockishos" do
  version "0.027"
  sha256 "4e1e3c95bb0a4c0b6e6b30b775dec477cd95fdf1308f7c9df02d9ce23b2a7068"

  url "https://github.com/8bittts/dockishOS/releases/download/v#{version}/DockishOS-#{version}.dmg",
      verified: "github.com/8bittts/dockishOS/"
  name "DockishOS"
  desc "Per-Space app bar for macOS"
  homepage "https://github.com/8bittts/dockishOS"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :sonoma"
  depends_on arch: :arm64

  app "DockishOS.app"

  zap trash: [
    "~/Library/Application Support/com.8bittts.dockishos",
    "~/Library/Caches/com.8bittts.dockishos",
    "~/Library/Preferences/com.8bittts.dockishos.plist",
    "~/Library/Saved Application State/com.8bittts.dockishos.savedState",
  ]
end
