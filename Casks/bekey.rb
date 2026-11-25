cask "bekey" do
  version "1.0.6"
  sha256 "0a3f3495707ae5c2470e9f2c256debf01815af4e45dd662815bd720a4fefcece"

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
