cask "localvoxtral" do
  version "0.8.4"
  sha256 "20eb046ca113233364708c7445ae0e52609eefcbc89a25f8699522ef7cbfe837"

  url "https://github.com/T0mSIlver/localvoxtral/releases/download/v#{version}/localvoxtral-v#{version}.zip"
  name "localvoxtral"
  desc "Realtime, fully local dictation for the menu bar"
  homepage "https://github.com/T0mSIlver/localvoxtral"

  livecheck do
    url "https://github.com/T0mSIlver/localvoxtral/releases/latest"
    strategy :github_latest
  end

  depends_on macos: :sequoia
  depends_on arch: :arm64

  app "localvoxtral.app"

  # Releases are ad-hoc signed, not notarized (see docs/roadmap.md). The
  # installer script (scripts/install.sh) clears quarantine and re-signs
  # locally before the bundle enters /Applications; replicate that here so
  # first launch works on macOS 15 and macOS 26 alike — macOS 26 can hang on
  # a foreign ad-hoc signature during Gatekeeper's first-exec scan unless the
  # bundle is re-signed locally.
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-cr", "#{appdir}/localvoxtral.app"]
    system_command "/usr/bin/codesign",
                   args: ["--force", "--deep", "--sign", "-", "#{appdir}/localvoxtral.app"]
  end

  zap trash: [
    "~/Library/Application Support/localvoxtral",
    "~/Library/Preferences/com.localvoxtral.app.plist",
  ]

  caveats <<~EOS
    macOS may silently drop the Accessibility grant after the app bundle is
    replaced (updates). If the dictation hotkey stops working, toggle
    localvoxtral off and on in System Settings → Privacy & Security →
    Accessibility.

    First launch runs a setup wizard: microphone + Accessibility permissions
    and a one-time engine/model download from Hugging Face.
  EOS
end
