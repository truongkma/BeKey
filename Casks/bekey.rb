cask "bekey" do
  version "1.0.0"
  sha256 "48043b74bccc2f1877a37662524d6625e9df15b495ff266932715caaa85c5318"

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
    # Replace a running older copy; apps reconnect on their next keystroke.
    system_command "/usr/bin/pkill", args: ["-x", "BeKey"], must_succeed: false
    system_command "#{app}/Contents/MacOS/BeKey", args: ["--install"], must_succeed: false
    system_command "/usr/bin/open", args: [app], must_succeed: false
  end

  uninstall quit: "vn.behemoth.inputmethod.BeKey"

  zap trash: "~/Library/Preferences/vn.behemoth.inputmethod.BeKey.plist"

  caveats <<~EOS
    First time only: System Settings > Keyboard > Input Sources > Edit > + > Vietnamese > BeKey.
  EOS
end
