cask "dockishos" do
  version "0.021"
  sha256 "490e1a4b2720482d2a6035a44785a92f90d54e75f181d13668ef638365efa9d8"

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
