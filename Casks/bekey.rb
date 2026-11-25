cask "bekey" do
  version "1.0.2"
  sha256 "b73a36cffb6a19ec6a12e1a3905b17ceddb73f83b20595a1250658d61297c305"

  url "https://github.com/truongkma/BeKey/releases/download/v#{version}/BeKey-#{version}.zip"
  name "BeKey"
  desc "Lightweight Vietnamese input method (Telex, VNI)"
  homepage "https://github.com/truongkma/BeKey"

  depends_on macos: ">= :ventura"

  input_method "BeKey.app"

  postflight do
    app = "#{Dir.home}/Library/Input Methods/BeKey.app"
    # Ad-hoc signed (no Apple Developer ID): drop quarantine so Gatekeeper lets macOS launch it.
    system_command "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", app]
    # Never kill a running BeKey: Electron/Chromium apps would lose their input-method connection
    # until reopened. An upgrade takes effect at the next login; a first install starts it now.
    unless system_command("/usr/bin/pgrep", args: ["-x", "BeKey"], must_succeed: false).success?
      system_command "#{app}/Contents/MacOS/BeKey", args: ["--install"], must_succeed: false
      system_command "/usr/bin/open", args: [app], must_succeed: false
    end
  end

  zap trash: "~/Library/Preferences/vn.behemoth.inputmethod.BeKey.plist"

  caveats <<~EOS
    First time only: System Settings > Keyboard > Input Sources > Edit > + > Vietnamese > BeKey.
    After an upgrade, the new version is used from your next login.
  EOS
end
