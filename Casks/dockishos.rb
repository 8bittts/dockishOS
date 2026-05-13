cask "dockishos" do
  version "0.019"
  sha256 "e9368fcf044ff4c29c1def615d9f9eed3390aee241a8aa8a25d4e1f525e4bcdf"

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
