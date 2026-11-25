# BeKey

**Bộ gõ tiếng Việt siêu nhẹ cho macOS** (Telex và VNI), viết bằng Swift trên InputMethodKit, là API bộ gõ chính thức của Apple.

> Không còn tình trạng "đang bật tiếng Việt mà gõ không ra dấu".

## Vì sao có BeKey?

Phần lớn bộ gõ tiếng Việt trên Mac chặn phím toàn hệ thống (event tap) rồi giả lập phím Backspace để sửa chữ. Cách này dễ hỏng khi macOS tự tắt event tap, khi mất quyền Accessibility sau cập nhật, hoặc khi app nhận Backspace giả không đúng thứ tự.

BeKey làm khác:

| | BeKey |
|---|---|
| Cách hoạt động | Input source chính thức của macOS (InputMethodKit) |
| Quyền Accessibility | **Không cần** |
| Gạch chân khi gõ | **Không**: chữ được ghi thẳng vào app, chỉ thay đúng phần bị đổi dấu |
| Dung lượng | ~170 KB, không thư viện ngoài, ~300 dòng Swift |
| Gõ tiếng Anh xen kẽ | Từ không thể là âm tiết tiếng Việt (`telex`, `class`, `html`) được giữ nguyên |
| Kiểm thử | Toàn bộ 6.600 âm tiết tiếng Việt, mỗi âm tiết gõ theo nhiều cách, đều cho kết quả đúng |

## Cài đặt

### Yêu cầu
- macOS 13 trở lên (đã thử trên macOS 26)
- Xcode hoặc Command Line Tools (`xcode-select --install`)

### Các bước

```sh
git clone https://github.com/truongkma/BeKey.git
cd BeKey
./build.sh install
```

Lệnh trên sẽ chạy test, build `BeKey.app`, chép vào `~/Library/Input Methods/` rồi mở trang cài đặt Bàn phím.

**Chỉ lần đầu**, thêm BeKey vào danh sách nguồn nhập:

1. **System Settings → Keyboard → Input Sources → Edit…**
2. Bấm **+** → chọn **Vietnamese** → chọn **BeKey** → **Add**
3. Nếu chưa thấy BeKey trong danh sách: đăng xuất rồi đăng nhập lại một lần.

> macOS 26 không cho app tự bật bộ gõ của bên thứ ba, nên bước này bắt buộc làm bằng tay.

### Cập nhật
```sh
git pull && ./build.sh install
```

### Gỡ cài đặt
```sh
pkill -x BeKey; rm -rf ~/Library/Input\ Methods/BeKey.app
```
Sau đó xoá BeKey khỏi **Input Sources**.

## Sử dụng

- **Bật/tắt tiếng Việt**: chuyển nguồn nhập bằng `Ctrl + Space` hoặc phím 🌐 (Globe), qua lại giữa BeKey và ABC.
- **Chọn kiểu gõ**: bấm biểu tượng **V** trên thanh menu → **Telex** hoặc **VNI**. Lựa chọn được lưu lại.
- **Gõ tắt hoặc phím chức năng** (`⌘`, `⌃`, `⌥`): BeKey nhường lại hoàn toàn cho app.

### Bảng gõ

| Kết quả | Telex | VNI |
|---|---|---|
| sắc · huyền · hỏi · ngã · nặng | `s` `f` `r` `x` `j` | `1` `2` `3` `4` `5` |
| xoá dấu thanh | `z` | `0` |
| â · ê · ô | `aa` `ee` `oo` | `a6` `e6` `o6` |
| ă | `aw` | `a8` |
| ơ · ư | `ow` `uw` (hoặc `w` đứng riêng → ư) | `o7` `u7` |
| ươ | `uow` hoặc `uwow` | `uo7` |
| đ | `dd` | `d9` |

Ví dụ: `Vieejt Nam` / `Vie65t Nam` → **Việt Nam**; `nguwowif` / `ngu7o72i` → **người**; `hoawcj` → **hoặc**.

### Mẹo
- **Dấu thanh gõ ở đâu cũng được**: `tieengs` hay `tiesng` đều ra **tiếng**.
- **Gõ phím dấu lần nữa để huỷ**: `aaa` → `aa`, `ddd` → `dd`.
- **Vị trí dấu kiểu mới**: `hoà`, `khoẻ`, `thuý`. Muốn kiểu cũ (`hòa`, `khỏe`, `thúy`) thì sửa `modernTone = false` trong `Sources/Engine.swift` rồi chạy lại `./build.sh install`.
- **Backspace** xoá phím vừa gõ trong từ đang gõ. Ví dụ `tieengs` rồi Backspace sẽ mất dấu sắc.

## Xử lý sự cố

| Hiện tượng | Cách xử lý |
|---|---|
| Không thấy BeKey trong danh sách Vietnamese | Đăng xuất rồi đăng nhập lại, sau đó thêm lại |
| Đã chọn BeKey nhưng gõ không ra dấu | Bộ gõ có thể không chạy: `open ~/Library/Input\ Methods/BeKey.app` (hoặc chạy lại `./build.sh install`) |
| App nào đó hiện gạch chân khi gõ | App đó không báo được vị trí con trỏ nên BeKey dùng chế độ gõ có gạch chân cho an toàn. Gõ vẫn đúng |

## Phát triển

```sh
./build.sh           # chạy test + build vào build/BeKey.app
./build.sh install   # build + cài
```

`./build.sh` luôn chạy test engine trước khi build. Test gồm các ca viết tay và bài kiểm tra vòng lặp cho mọi âm tiết trong `Tests/syllables.txt` (lấy từ từ điển hunspell tiếng Việt của LibreOffice): chuyển âm tiết thành phím gõ Telex/VNI theo nhiều cách, rồi so với kết quả engine trả về.

| File | Vai trò |
|---|---|
| `Sources/Engine.swift` | Chuyển chuỗi phím thành chữ Việt (không giữ trạng thái) |
| `Sources/InputController.swift` | Nối với InputMethodKit: ghi chữ vào app, menu Telex/VNI |
| `Sources/main.swift` | Khởi động bộ gõ, lệnh `--install` |
| `Tests/main.swift` | Test engine |
| `tools/icon.swift` | Tạo biểu tượng **V** trên thanh menu |

## Giấy phép

[MIT](LICENSE)
