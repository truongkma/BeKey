# BeKey

**Bộ gõ tiếng Việt nhẹ và ổn định cho macOS**, hỗ trợ Telex và VNI.

BeKey là một input method chính thức của macOS (InputMethodKit), viết bằng Swift, không thư viện ngoài. BeKey chỉ hoạt động khi bạn chọn nó làm nguồn nhập, nên không có tình trạng *"đang bật tiếng Việt mà gõ không ra dấu"* do hai bộ gõ tranh nhau.

## Tên gọi

**"Be"** trong BeKey là viết tắt của **Behemoth**. BeKey được một thành viên của công ty Behemoth phát triển trong quá trình làm việc tại công ty, với mong muốn có một bộ gõ tiếng Việt gọn nhẹ và đáng tin cậy cho công việc hằng ngày. Tên gọi này là lời ghi nhận dành cho Behemoth.

## Điểm nổi bật

- **Không gạch chân, gõ đúng ở mọi ứng dụng:** trình duyệt, Slack, VS Code (cả trình soạn thảo lẫn terminal), Orca, iTerm2, TextEdit… BeKey sửa dấu bằng phím Backspace thật và chữ mới, chèn đúng vào chỗ của phím vừa gõ, nên gõ nhanh cũng không bị lệch thứ tự, mất dấu hay lặp chữ. Cách này cần quyền **Accessibility** (xem phần thiết lập).
- **Chỉ hoạt động khi BeKey là nguồn nhập đang chọn** và bạn đang gõ trong một ô nhập. Chuyển sang ABC là BeKey đứng ngoài hoàn toàn.
- **Gõ tiếng Anh xen kẽ:** từ không thể là âm tiết tiếng Việt (`class`, `html`, `telex`) được giữ nguyên.
- **Nhẹ:** khoảng 8 MB RAM, không thư viện ngoài, không kết nối mạng, không lưu lại nội dung bạn gõ.

## Cài đặt

Yêu cầu macOS 13 trở lên, chip Apple hoặc Intel.

### Cách 1: Homebrew (khuyên dùng)

```sh
brew tap truongkma/bekey https://github.com/truongkma/BeKey
brew trust truongkma/bekey      # Homebrew 7+ yêu cầu tin cậy tap bên thứ ba
brew install --cask bekey
```

### Cách 2: Build từ mã nguồn

Cần Xcode hoặc Command Line Tools (`xcode-select --install`).

```sh
git clone https://github.com/truongkma/BeKey.git
cd BeKey
./build.sh install
```

### Thiết lập lần đầu

macOS không cho ứng dụng tự bật bộ gõ, nên bạn thêm BeKey một lần:

1. Mở **System Settings → Keyboard → Input Sources → Edit…**
2. Bấm **+** → chọn **Vietnamese** → chọn **BeKey** → **Add**.
3. Nếu chưa thấy BeKey trong danh sách: **đăng xuất rồi đăng nhập lại** một lần, sau đó làm lại bước 2.
4. Cấp quyền **Accessibility**: lần đầu chạy, BeKey hỏi quyền này. Bấm **Open System Settings** rồi bật **BeKey** trong **Privacy & Security → Accessibility** (nếu không thấy, bấm **+** và chọn `~/Library/Input Methods/BeKey.app`, bấm `⌘⇧G` để dán đường dẫn). Không có quyền này BeKey vẫn gõ được, nhưng theo cách cũ: có thể sai dấu sau khi xoá giữa từ, và có gạch chân trong Orca, VS Code.
5. Nếu bạn đang dùng bộ gõ tiếng Việt khác (OpenKey, EVKey, Unikey…), hãy tắt nó và bỏ chế độ tự chạy khi đăng nhập, để hai bộ gõ không cùng xử lý một phím. Nên xoá cả bộ **Vietnamese – Telex/Simple Telex** có sẵn của macOS khỏi Input Sources: bộ này có gạch chân khi gõ và dễ bị chọn nhầm khi bấm `Ctrl + Space`.

## Sử dụng

- **Bật/tắt tiếng Việt:** chuyển nguồn nhập giữa **BeKey** và **ABC** bằng `Ctrl + Space` hoặc phím 🌐. Muốn mỗi ứng dụng tự nhớ nguồn nhập riêng, bật **Automatically switch to a document's input source** trong cùng trang Input Sources.
- **Chọn kiểu gõ:** bấm biểu tượng **V** trên thanh menu → **Telex** hoặc **VNI**.

| Kết quả | Telex | VNI |
|---|---|---|
| sắc · huyền · hỏi · ngã · nặng | `s` `f` `r` `x` `j` | `1` `2` `3` `4` `5` |
| xoá dấu thanh | `z` | `0` |
| â · ê · ô | `aa` `ee` `oo` | `a6` `e6` `o6` |
| ă | `aw` | `a8` |
| ơ · ư | `ow` `uw` (hoặc `w` đứng riêng → ư) | `o7` `u7` |
| ươ | `uow` hoặc `uwow` | `uo7` |
| đ | `dd` | `d9` |

Ví dụ: `Vieejt Nam` / `Vie65t Nam` → **Việt Nam**; `nguwowif` → **người**; `hoawcj` → **hoặc**.

**Mẹo**
- Dấu thanh gõ ở đâu trong từ cũng được: `tieengs` hay `tiesng` đều ra **tiếng**.
- Gõ phím dấu lần nữa để huỷ: `tesst` → `test`, `aaa` → `aa`, `ddd` → `dd`.
- Dấu đặt theo kiểu mới (`hoà`, `khoẻ`, `thuý`). Muốn kiểu cũ (`hòa`, `khỏe`, `thúy`): sửa `modernTone = false` trong `Sources/Engine.swift` rồi build lại.

## Cập nhật và gỡ cài đặt

| | Homebrew | Từ mã nguồn |
|---|---|---|
| Cập nhật | `brew upgrade --cask bekey` | `git pull && ./build.sh install` |

Bản cập nhật qua Homebrew có hiệu lực từ lần đăng nhập sau (BeKey đang chạy không bị tắt, để các ứng dụng không mất kết nối). Cập nhật từ mã nguồn khởi động lại BeKey ngay; nếu ứng dụng nào gõ không ra dấu, thoát hẳn (⌘Q) rồi mở lại.
| Gỡ cài đặt | `brew uninstall --cask bekey` | `pkill -x BeKey; rm -rf ~/Library/Input\ Methods/BeKey.app` |

Sau khi gỡ, xoá BeKey khỏi **Input Sources**.

## Xử lý sự cố

| Hiện tượng | Cách xử lý |
|---|---|
| Không thấy BeKey khi bấm **+** | Đăng xuất rồi đăng nhập lại, sau đó thêm lại |
| Không thấy biểu tượng **V** trên thanh menu (thường sau khi cài lại) | Trong **Input Sources**, xoá BeKey (**−**) rồi thêm lại (**+**) |
| Đã chọn BeKey nhưng gõ không ra dấu | Chạy `open ~/Library/Input\ Methods/BeKey.app`. Nếu vẫn không được ở một ứng dụng đã mở từ trước, thoát hẳn ứng dụng đó (⌘Q) rồi mở lại |
| Có ký tự lạ hoặc chữ bị lặp | Kiểm tra xem còn bộ gõ tiếng Việt nào khác đang chạy không và tắt nó |
| Có gạch chân khi gõ | Nhìn biểu tượng trên thanh menu: nếu không phải **V** thì bạn đang dùng bộ Telex của macOS; xoá nó khỏi Input Sources. Nếu đúng là BeKey: kiểm tra quyền **Accessibility** của BeKey (bật lại công tắc), rồi chạy `pkill -x BeKey; open ~/Library/Input\ Methods/BeKey.app` |
| Trong terminal, 1–2 ký tự bị gạch chân rồi mất (vd. khi gõ "gõ", "tôi") | Không phải BeKey: plugin **zsh-syntax-highlighting** gạch chân chữ trùng tên thư mục/lệnh (`go`, `to`…) trong lúc gõ dở. Muốn tắt: thêm `ZSH_HIGHLIGHT_STYLES[path]=none` và `ZSH_HIGHLIGHT_STYLES[path_prefix]=none` vào cuối `~/.zshrc` |

## Phát triển

```sh
./build.sh           # chạy test và build vào build/BeKey.app
./build.sh install   # build và cài vào ~/Library/Input Methods
```

`./build.sh` luôn chạy test engine trước khi build: các ca viết tay và bài kiểm tra vòng lặp cho toàn bộ 6.602 âm tiết trong `Tests/syllables.txt` (lấy từ từ điển hunspell tiếng Việt của LibreOffice), gõ theo nhiều cách bằng Telex và VNI. Ngoài ra có bài kiểm tra `InputController` với một ô nhập giả báo vị trí con trỏ trễ (như Chrome, Slack khi gõ nhanh). Phần ghép chữ của cách gõ bằng phím thật (`Composer`) được kiểm tra trên một màn hình giả chỉ nhận phím, như terminal.

| File | Vai trò |
|---|---|
| `Sources/Engine.swift` | Chuyển chuỗi phím thành chữ Việt (không giữ trạng thái) |
| `Sources/KeyTap.swift` | Gõ bằng phím thật (event tap, cần Accessibility): chặn phím, chèn Backspace và chữ đúng |
| `Sources/InputController.swift` | Kết nối InputMethodKit: cho KeyTap biết ô nhập đang dùng; khi chưa có Accessibility thì tự ghi chữ vào ứng dụng; menu Telex/VNI |
| `Sources/SecureInput.swift` | Tự bật lại BeKey khi ô mật khẩu (Secure Input) đã ép sang ABC mà macOS không trả lại |
| `Sources/main.swift` | Khởi động bộ gõ, lệnh `--install` |
| `Casks/bekey.rb` | Công thức cài đặt qua Homebrew |

### Phát hành bản mới

1. Tăng `CFBundleShortVersionString` trong `Info.plist`.
2. `./build.sh`, rồi đóng gói: `ditto -c -k --keepParent build/BeKey.app BeKey-<version>.zip && rm -rf build/BeKey.app` (đừng để lại bản sao `BeKey.app` thứ hai trên máy: macOS sẽ loại BeKey khỏi danh sách bộ gõ đã bật).
3. Tạo GitHub Release `v<version>` kèm file zip.
4. Cập nhật `version` và `sha256` (`shasum -a 256 BeKey-<version>.zip`) trong `Casks/bekey.rb`, commit và push.

## Giấy phép

[MIT](LICENSE)
