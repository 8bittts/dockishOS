cask "dockishos" do
  version "0.029"
  sha256 "b43aac6d20360a6e1ccffa75d90ca390a2e658d1c4b3e0443f93693a06bcbc32"

  url "https://github.com/8bittts/dockishOS/releases/download/v#{version}/DockishOS-#{version}.dmg",
      verified: "github.com/8bittts/dockishOS/"
  name "DockishOS"
  desc "Per-Space app bar"
  homepage "https://github.com/8bittts/dockishOS"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on arch: :arm64
  depends_on macos: :golden_gate

  app "DockishOS.app"

  zap trash: [
    "~/Library/Application Support/com.8bittts.dockishos",
    "~/Library/Caches/com.8bittts.dockishos",
    "~/Library/Preferences/com.8bittts.dockishos.plist",
    "~/Library/Saved Application State/com.8bittts.dockishos.savedState",
  ]
end
