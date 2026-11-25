# BeKey

**Bộ gõ tiếng Việt nhẹ và ổn định cho macOS**, hỗ trợ Telex và VNI.

BeKey là một input method chính thức của macOS (InputMethodKit), viết bằng Swift, khoảng 300 dòng, không cần quyền Accessibility và không chạy ngầm chặn phím. Vì vậy không còn tình trạng *"đang bật tiếng Việt mà gõ không ra dấu"*.

## Tên gọi

**"Be"** trong BeKey là viết tắt của **Behemoth**. BeKey được một thành viên của công ty Behemoth phát triển trong quá trình làm việc tại công ty, với mong muốn có một bộ gõ tiếng Việt gọn nhẹ và đáng tin cậy cho công việc hằng ngày. Tên gọi này là lời ghi nhận dành cho Behemoth.

## Điểm nổi bật

- **Ổn định:** chạy như một nguồn nhập (input source) của macOS, không dùng event tap, không giả lập phím Backspace.
- **Không gạch chân** trong phần lớn ứng dụng: chữ được ghi thẳng vào ô nhập. Trong terminal (Orca, cmux, VS Code, iTerm2…) BeKey sửa dấu bằng ký tự xoá lùi, cũng không gạch chân.
- **Gõ tiếng Anh xen kẽ:** từ không thể là âm tiết tiếng Việt (`class`, `html`, `telex`) được giữ nguyên.
- **Nhẹ:** khoảng 8 MB RAM, không thư viện ngoài, không kết nối mạng, không lưu lại nội dung bạn gõ.

## Cài đặt

Yêu cầu macOS 13 trở lên.

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
4. Nếu bạn đang dùng bộ gõ tiếng Việt khác (OpenKey, EVKey, Unikey…), hãy tắt nó và bỏ chế độ tự chạy khi đăng nhập, để hai bộ gõ không cùng xử lý một phím. Nên xoá cả bộ **Vietnamese – Telex/Simple Telex** có sẵn của macOS khỏi Input Sources: bộ này có gạch chân khi gõ và dễ bị chọn nhầm khi bấm `Ctrl + Space`.

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
| Thỉnh thoảng có gạch chân | Nhìn biểu tượng trên thanh menu: nếu không phải **V** thì bạn đang dùng bộ Telex của macOS; xoá nó khỏi Input Sources |

## Phát triển

```sh
./build.sh           # chạy test và build vào build/BeKey.app
./build.sh install   # build và cài vào ~/Library/Input Methods
```

`./build.sh` luôn chạy test engine trước khi build: các ca viết tay và bài kiểm tra vòng lặp cho toàn bộ 6.602 âm tiết trong `Tests/syllables.txt` (lấy từ từ điển hunspell tiếng Việt của LibreOffice), gõ theo nhiều cách bằng Telex và VNI.

| File | Vai trò |
|---|---|
| `Sources/Engine.swift` | Chuyển chuỗi phím thành chữ Việt (không giữ trạng thái) |
| `Sources/InputController.swift` | Kết nối InputMethodKit: ghi chữ vào ứng dụng, menu Telex/VNI |
| `Sources/main.swift` | Khởi động bộ gõ, lệnh `--install` |
| `Casks/bekey.rb` | Công thức cài đặt qua Homebrew |

### Phát hành bản mới

1. Tăng `CFBundleShortVersionString` trong `Info.plist`.
2. `./build.sh`, rồi đóng gói: `ditto -c -k --keepParent build/BeKey.app BeKey-<version>.zip`.
3. Tạo GitHub Release `v<version>` kèm file zip.
4. Cập nhật `version` và `sha256` (`shasum -a 256 BeKey-<version>.zip`) trong `Casks/bekey.rb`, commit và push.

## Giấy phép

[MIT](LICENSE)
