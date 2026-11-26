cask "bekey" do
  version "1.0.10"
  sha256 "0afdbe1df4bf90f3b118cbccc52a92cb132f70c1f858073610f59df613b603af"

  url "https://github.com/truongkma/BeKey/releases/download/v#{version}/BeKey-#{version}.zip"
  name "BeKey"
  desc "Lightweight Vietnamese input method (Telex, VNI)"
  homepage "https://github.com/truongkma/BeKey"

  depends_on macos: :ventura

  input_method "BeKey.app"

  postflight do
    app = "#{Dir.home}/Library/Input Methods/BeKey.app"
    # Ad-hoc signed (no Apple Developer ID): drop quarantine so Gatekeeper lets macOS launch it.
    system_command "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", app]
    # An upgrade deletes and replaces the bundle, which drops BeKey from the enabled input sources
    # ("inactive"): always re-register and re-enable. This does not stop the running BeKey.
    system_command "#{app}/Contents/MacOS/BeKey", args: ["--install"], must_succeed: false
    # Never kill a running BeKey: Electron/Chromium apps would lose their input-method connection
    # until reopened. An upgrade takes effect at the next login; a first install starts it now.
    unless system_command("/usr/bin/pgrep", args: ["-x", "BeKey"], must_succeed: false).success?
      system_command "/usr/bin/open", args: [app], must_succeed: false
    end
  end

  zap trash: "~/Library/Preferences/vn.behemoth.inputmethod.BeKey.plist"

  caveats <<~EOS
    First time only: System Settings > Keyboard > Input Sources > Edit > + > Vietnamese > BeKey.
    Then allow BeKey in System Settings > Privacy & Security > Accessibility when asked: it types
    with real key events, which is what keeps every app correct and free of underlines.
    After an upgrade, the new version is used from your next login. To use it now:
      pkill -x BeKey; open ~/Library/Input\\ Methods/BeKey.app
  EOS
end
