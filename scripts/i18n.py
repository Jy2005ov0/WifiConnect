#!/usr/bin/env python3
"""Translations for both apps: English, Bahasa Melayu, Simplified Chinese, Japanese and Tamil.

One table feeds both platforms:
  * Android: android/app/src/main/res/values{,-ms,-zh,-ja,-ta}/strings.xml
  * iOS:     ios/Shared/Localizable.xcstrings (keys are the English text)

Japanese and Tamil live in i18n_more.py, keyed by the English text.

Usage: i18n.py   (rewrites both)
"""
import json
import re
from pathlib import Path

from i18n_more import MORE

ROOT = Path(__file__).resolve().parent.parent

# (Android resource name or None for iOS-only text, English, Malay, Chinese)
TABLE = [
    ("app_name", "WiFi Connect", "WiFi Connect", "WiFi Connect"),
    ("main_title", "Campus Wi-Fi", "Wi-Fi Kampus", "校园 Wi-Fi"),
    ("settings_title", "Settings", "Tetapan", "设置"),
    ("back", "Back", "Kembali", "返回"),
    ("cancel", "Cancel", "Batal", "取消"),
    ("done", "Done", "Selesai", "完成"),
    ("not_set", "Not Set", "Belum Ditetapkan", "未设置"),
    ("on", "On", "Hidup", "开"),
    ("off", "Off", "Mati", "关"),
    ("selected", "Selected", "Dipilih", "已选择"),
    ("password", "Password", "Kata Laluan", "密码"),
    ("show_password", "Show password", "Tunjuk kata laluan", "显示密码"),
    ("hide_password", "Hide password", "Sembunyi kata laluan", "隐藏密码"),
    ("network_name", "Network Name", "Nama Rangkaian", "网络名称"),

    ("row_network", "Network", "Rangkaian", "网络"),
    ("row_student_id", "Student ID", "ID Pelajar", "学号"),
    ("language", "Language", "Bahasa", "语言"),
    ("language_system", "Same as Phone", "Sama seperti Telefon", "跟随手机"),

    ("row_auto_sign_in", "Auto Sign-In", "Log Masuk Automatik", "自动登录"),

    ("button_connect", "Connect", "Sambung", "连接"),
    ("button_try_again", "Try Again", "Cuba Lagi", "重试"),
    ("button_disconnect", "Disconnect", "Putuskan Sambungan", "断开连接"),
    ("button_add_student_id", "Add Student ID", "Tambah ID Pelajar", "添加学号"),
    ("hint_tap_connect", "Tap to Connect", "Ketik untuk Sambung", "点按以连接"),
    ("hint_tap_disconnect", "Tap to Disconnect", "Ketik untuk Putuskan", "点按以断开连接"),
    ("hint_tap_try_again", "Tap to Try Again", "Ketik untuk Cuba Lagi", "点按以重试"),
    ("sign_out", "Sign Out", "Log Keluar", "退出登录"),

    ("status_welcome", "Welcome", "Selamat Datang", "欢迎"),
    ("welcome_detail", "Ready to sign in to campus Wi-Fi.", "Sedia untuk log masuk ke Wi-Fi kampus.", "随时可以登录校园 Wi-Fi。"),
    ("welcome_swipe", "Swipe up to start", "Leret ke atas untuk mula", "向上轻扫开始"),
    ("status_welcome_detail", "Add your student ID and password to get started.",
     "Tambah ID pelajar dan kata laluan anda untuk bermula.", "添加你的学号和密码即可开始使用。"),
    ("status_ready", "Ready", "Sedia", "准备就绪"),
    ("status_ready_detail", "Join your school's Wi-Fi, then tap the circle.",
     "Sertai Wi-Fi universiti anda, kemudian ketik bulatan.", "连接学校的 Wi-Fi，然后点按圆圈。"),
    ("status_signing_in", "Signing In…", "Sedang Log Masuk…", "正在登录…"),
    ("status_signing_in_detail", "Talking to your school's login page.",
     "Sedang berhubung dengan halaman log masuk universiti anda.", "正在与学校的登录页面通信。"),
    ("status_connected", "Connected", "Bersambung", "已连接"),
    ("status_failed", "Couldn't Sign In", "Tidak Dapat Log Masuk", "无法登录"),
    ("status_signed_out", "Signed Out", "Telah Log Keluar", "已退出登录"),
    ("status_signed_out_detail", "You've signed out of the campus Wi-Fi.",
     "Anda telah log keluar daripada Wi-Fi kampus.", "你已退出校园 Wi-Fi。"),
    ("result_signed_in", "You're signed in and ready to go.",
     "Anda telah log masuk dan sedia untuk digunakan.", "你已登录，可以上网了。"),
    ("result_already_online", "You're already online.", "Anda sudah pun dalam talian.", "你已经在线。"),

    ("error_missing_credentials", "Add your student ID and password in Settings first.",
     "Tambah ID pelajar dan kata laluan anda dalam Tetapan dahulu.", "请先在“设置”中添加学号和密码。"),
    ("error_not_on_wifi", "Couldn't reach the Wi-Fi. Make sure you're connected to your school's network.",
     "Tidak dapat mencapai Wi-Fi. Pastikan anda bersambung ke rangkaian universiti anda.",
     "无法连接 Wi-Fi。请确认你已连接到学校的网络。"),
    ("error_form_not_found",
     "Couldn't find a login form on your school's page. Set the login page manually in Settings.",
     "Tidak menemui borang log masuk pada halaman universiti anda. Tetapkan halaman log masuk secara manual dalam Tetapan.",
     "在学校的页面上找不到登录表单。请在“设置”中手动设置登录页面。"),
    ("error_invalid_url", "The custom login URL in Settings isn't valid.",
     "URL log masuk tersuai dalam Tetapan tidak sah.", "“设置”中的自定义登录网址无效。"),
    ("error_network", "The login page didn't respond: {0}",
     "Halaman log masuk tidak memberi respons: {0}", "登录页面没有响应：{0}"),
    ("error_still_offline", "Signed in, but there's still no internet. Check your student ID and password.",
     "Sudah log masuk, tetapi masih tiada internet. Semak ID pelajar dan kata laluan anda.",
     "已登录，但仍无法上网。请检查你的学号和密码。"),
    ("error_no_sign_out_link",
     "Your school's login page didn't show a sign-out link. You can add one in Settings › Login Page.",
     "Halaman log masuk universiti anda tidak menunjukkan pautan log keluar. Anda boleh menambahnya dalam Tetapan › Halaman Log Masuk.",
     "学校的登录页面没有提供退出链接。你可以在“设置 › 登录页面”中添加。"),
    ("error_still_signed_in", "The sign-out link didn't sign you out.",
     "Pautan log keluar tidak melog keluar anda.", "退出链接未能让你退出登录。"),

    ("settings_account", "Account", "Akaun", "账户"),
    ("settings_account_footer", "Encrypted on this phone and only sent to your school's login page.",
     "Disulitkan pada telefon ini dan hanya dihantar ke halaman log masuk universiti anda.",
     "已在此手机上加密，只会发送到学校的登录页面。"),
    ("settings_school_wifi", "School Wi-Fi", "Wi-Fi Universiti", "学校 Wi-Fi"),
    ("settings_school_wifi_footer", "The Wi-Fi name you join on campus.",
     "Nama Wi-Fi yang anda sertai di kampus.", "你在校园里连接的 Wi-Fi 名称。"),
    ("settings_automatic", "Automatic Sign-In", "Log Masuk Automatik", "自动登录"),
    ("settings_automatic_footer",
     "Signs in by itself whenever your phone joins a Wi-Fi network with a login page, even when the app is closed.",
     "Log masuk sendiri setiap kali telefon anda menyertai rangkaian Wi-Fi yang mempunyai halaman log masuk, walaupun aplikasi ditutup.",
     "每当手机连接到带登录页面的 Wi-Fi 网络时自动登录，即使应用已关闭。"),
    ("wifi_check_title", "Only on School Wi-Fi", "Hanya pada Wi-Fi Universiti", "仅限学校 Wi-Fi"),
    ("wifi_check_on", "Signs in automatically only on {0}.", "Log masuk secara automatik hanya pada {0}.", "仅在 {0} 上自动登录。"),
    ("wifi_check_needs_permission",
     "Allow location access so automatic sign-in only fills in {0}'s login page. Android needs it to read the Wi-Fi name; your location isn't used or saved.",
     "Benarkan akses lokasi supaya log masuk automatik hanya mengisi halaman log masuk {0}. Android memerlukannya untuk membaca nama Wi-Fi; lokasi anda tidak digunakan atau disimpan.",
     "允许位置权限，自动登录就只会填写 {0} 的登录页面。Android 需要此权限才能读取 Wi-Fi 名称；不会使用或保存你的位置。"),
    ("wifi_check_location_off",
     "Turn on Location so the app can read the Wi-Fi name. Until then, automatic sign-in fills in any Wi-Fi login page.",
     "Hidupkan Lokasi supaya aplikasi boleh membaca nama Wi-Fi. Sehingga itu, log masuk automatik mengisi mana-mana halaman log masuk Wi-Fi.",
     "请打开定位，以便应用读取 Wi-Fi 名称。在此之前，自动登录会填写任何 Wi-Fi 登录页面。"),
    ("wifi_check_allow", "Allow", "Benarkan", "允许"),
    ("wifi_check_turn_on", "Turn On", "Hidupkan", "打开"),
    ("error_other_network", "On {0}, not your school Wi-Fi, so the app didn't sign in.",
     "Pada {0}, bukan Wi-Fi universiti anda, jadi aplikasi tidak log masuk.", "当前是 {0}，不是学校的 Wi-Fi，因此没有登录。"),
    ("setting_auto_login", "Sign In Automatically", "Log Masuk Secara Automatik", "自动登录"),
    ("setting_stay_signed_in", "Stay Signed In", "Kekal Log Masuk", "保持登录"),
    ("setting_stay_signed_in_footer",
     "Stay Signed In checks every 15 minutes and signs you back in if the Wi-Fi logs you out.",
     "Kekal Log Masuk menyemak setiap 15 minit dan melog masuk semula jika Wi-Fi melog keluar anda.",
     "“保持登录”每 15 分钟检查一次，如果 Wi-Fi 让你退出登录，会自动重新登录。"),
    ("setting_notify", "Notify When Connected", "Beritahu Apabila Bersambung", "连接后通知"),
    ("appearance", "Appearance", "Penampilan", "外观"),
    ("appearance_system", "System", "Sistem", "跟随系统"),
    ("appearance_light", "Light", "Cerah", "浅色"),
    ("appearance_dark", "Dark", "Gelap", "深色"),
    ("settings_login_page", "Login Page", "Halaman Log Masuk", "登录页面"),
    ("settings_login_page_footer",
     "The login page is found automatically, even when each building uses a different address. If that doesn't work, join the school Wi-Fi and tap Detect Login Page, or fill it in manually. Enter just the path, like /login, so it works in every building.",
     "Halaman log masuk ditemui secara automatik, walaupun setiap bangunan menggunakan alamat berbeza. Jika tidak berjaya, sertai Wi-Fi universiti dan ketik Kesan Halaman Log Masuk, atau isi secara manual. Masukkan laluan sahaja, seperti /login, supaya ia berfungsi di setiap bangunan.",
     "即使每栋楼的地址不同，也会自动找到登录页面。如果无法找到，请连接学校 Wi-Fi 后点按“检测登录页面”，或手动填写。只需输入路径（例如 /login），这样在每栋楼都能使用。"),
    ("setting_manual_login_page", "Set Login Page Manually", "Tetapkan Halaman Log Masuk Secara Manual", "手动设置登录页面"),
    ("field_url", "URL or Path", "URL atau Laluan", "网址或路径"),
    ("field_method", "Method", "Kaedah", "方法"),
    ("field_id", "ID Field", "Medan ID", "学号字段"),
    ("field_password", "Password Field", "Medan Kata Laluan", "密码字段"),
    ("field_sign_out", "Sign-Out URL", "URL Log Keluar", "退出网址"),
    ("field_extra", "Extra fields, one name=value per line", "Medan tambahan, satu nama=nilai setiap baris",
     "额外字段，每行一个“名称=值”"),
    ("detect_login_page", "Detect Login Page", "Kesan Halaman Log Masuk", "检测登录页面"),
    ("detect_already_online",
     "You're already online, so there's no login page to detect. Try again right after joining the school Wi-Fi.",
     "Anda sudah dalam talian, jadi tiada halaman log masuk untuk dikesan. Cuba lagi sebaik sahaja menyertai Wi-Fi universiti.",
     "你已经在线，所以没有可检测的登录页面。请在刚连接学校 Wi-Fi 后再试。"),
    ("detect_found",
     "Found the login page at {0}. Automatic sign-in works here and in other buildings, so there's nothing to set up.",
     "Halaman log masuk ditemui di {0}. Log masuk automatik berfungsi di sini dan di bangunan lain, jadi tiada apa-apa untuk ditetapkan.",
     "已在 {0} 找到登录页面。自动登录在这里和其他楼都能使用，无需额外设置。"),
    ("detect_found_updated", "Found the login page at {0}. The details above have been updated.",
     "Halaman log masuk ditemui di {0}. Butiran di atas telah dikemas kini.", "已在 {0} 找到登录页面。上面的信息已更新。"),

    ("lock_section", "Security", "Keselamatan", "安全"),
    ("lock_title", "Require Fingerprint or Screen Lock", "Perlukan Cap Jari atau Kunci Skrin", "需要指纹或屏幕锁"),
    ("lock_footer",
     "Asks for your fingerprint, face or screen lock before showing Settings, where your password is saved.",
     "Meminta cap jari, wajah atau kunci skrin anda sebelum menunjukkan Tetapan, tempat kata laluan anda disimpan.",
     "在显示保存密码的“设置”之前，要求验证指纹、面容或屏幕锁。"),
    ("lock_open_settings", "Unlock to see your student ID and password",
     "Buka kunci untuk melihat ID pelajar dan kata laluan anda", "解锁以查看学号和密码"),
    ("lock_confirm", "Confirm it's you to change the app lock",
     "Sahkan ini anda untuk menukar kunci aplikasi", "请确认是你本人以更改应用锁"),

    ("history_title", "Sign-In History", "Sejarah Log Masuk", "登录记录"),
    ("history_help", "Help", "Bantuan", "帮助"),
    ("history_recent", "Recent", "Terkini", "最近"),
    ("history_copy", "Copy Diagnostics", "Salin Diagnostik", "复制诊断信息"),
    ("history_copied", "Copied", "Disalin", "已复制"),
    ("history_copy_footer",
     "If signing in doesn't work, copy this report and send it to whoever helps you with the app. It includes the login page details but never your password.",
     "Jika log masuk tidak berjaya, salin laporan ini dan hantar kepada sesiapa yang membantu anda dengan aplikasi ini. Ia mengandungi butiran halaman log masuk tetapi tidak sekali-kali kata laluan anda.",
     "如果无法登录，请复制这份报告并发送给帮助你使用此应用的人。报告包含登录页面信息，但绝不包含你的密码。"),
    ("history_empty", "No sign-ins yet. They'll appear here, including automatic ones.",
     "Belum ada log masuk. Ia akan dipaparkan di sini, termasuk yang automatik.",
     "还没有登录记录。登录记录（包括自动登录）会显示在这里。"),
    ("history_clear", "Clear", "Kosongkan", "清除"),
    ("history_clear_confirm", "Clear sign-in history?", "Kosongkan sejarah log masuk?", "清除登录记录？"),
    ("history_signed_in", "Signed In", "Log Masuk", "已登录"),
    ("history_already_online", "Already Online", "Sudah Dalam Talian", "已在线"),
    ("trigger_app", "From the app", "Daripada aplikasi", "在应用中"),
    ("trigger_automatic", "Automatic", "Automatik", "自动"),
    ("trigger_tile", "Quick Settings tile", "Jubin Tetapan Pantas", "快捷设置图块"),
    ("trigger_widget", "Widget", "Widget", "小组件"),
    ("trigger_background", "Stay Signed In", "Kekal Log Masuk", "保持登录"),

    ("notify_channel", "Wi-Fi sign-in", "Log masuk Wi-Fi", "Wi-Fi 登录"),
    ("notify_connected_title", "Connected to {0}", "Bersambung ke {0}", "已连接到 {0}"),
    ("notify_connected_body", "You're signed in and online.", "Anda telah log masuk dan dalam talian.", "你已登录并在线。"),
    ("notify_failed_title", "Couldn't sign in to campus Wi-Fi", "Tidak dapat log masuk ke Wi-Fi kampus", "无法登录校园 Wi-Fi"),

    ("speed_title", "Speed", "Kelajuan", "速度"),
    ("speed_test", "Test", "Uji", "测试"),
    ("speed_testing", "Testing…", "Menguji…", "正在测试…"),
    ("speed_unavailable", "No connection", "Tiada sambungan", "无连接"),
    ("speed_result", "{0:d} ms · {1} Mbps", "{0:d} ms · {1} Mbps", "{0:d} 毫秒 · {1} Mbps"),

    ("speedtest_title", "Speed Test", "Ujian Kelajuan", "网速测试"),
    ("speedtest_start", "Start", "Mula", "开始"),
    ("speedtest_stop", "Stop", "Henti", "停止"),
    ("speedtest_again", "Test Again", "Uji Semula", "重新测试"),
    ("speedtest_download", "Download", "Muat Turun", "下载"),
    ("speedtest_upload", "Upload", "Muat Naik", "上传"),
    ("speedtest_ping", "Ping", "Ping", "延迟"),
    ("speedtest_jitter", "Jitter", "Ketar", "抖动"),
    ("speedtest_failed_title", "Couldn't Test", "Tidak Dapat Menguji", "无法测试"),
    ("speedtest_failed", "Couldn't reach the test server. Make sure you're connected to the Wi-Fi and online.",
     "Tidak dapat mencapai pelayan ujian. Pastikan anda bersambung ke Wi-Fi dan dalam talian.",
     "无法连接测试服务器。请确认你已连接 Wi-Fi 并且可以上网。"),
    ("speedtest_footer", "Tested over the Wi-Fi only, using Cloudflare's speed test servers. On fast Wi-Fi a test can use over 100 MB of data.",
     "Diuji melalui Wi-Fi sahaja, menggunakan pelayan ujian kelajuan Cloudflare. Pada Wi-Fi yang laju, satu ujian boleh menggunakan lebih 100 MB data.",
     "仅通过 Wi-Fi 测试，使用 Cloudflare 的测速服务器。在高速 Wi-Fi 上，一次测试可能消耗超过 100 MB 流量。"),

    ("tile_label", "Campus Wi-Fi", "Wi-Fi Kampus", "校园 Wi-Fi"),
    ("tile_signing_in", "Signing in…", "Sedang log masuk…", "正在登录…"),
    ("tile_tap_to_sign_in", "Tap to sign in", "Ketik untuk log masuk", "点按登录"),
    ("tile_tap_to_retry", "Tap to try again", "Ketik untuk cuba lagi", "点按重试"),
    ("tile_signed_in_at", "Signed in {0}", "Log masuk {0}", "{0} 已登录"),

    ("share_title", "Share Setup", "Kongsi Tetapan", "分享设置"),
    ("share_with_friends", "Share Setup with Friends", "Kongsi Tetapan dengan Rakan", "与朋友分享设置"),
    ("share_explain",
     "Ask a classmate to scan this with their phone's camera. WiFi Connect opens with your Wi-Fi and login page settings filled in.",
     "Minta rakan sekelas mengimbas kod ini dengan kamera telefon mereka. WiFi Connect akan dibuka dengan tetapan Wi-Fi dan halaman log masuk anda telah diisi.",
     "请同学用手机相机扫描此二维码。WiFi Connect 会打开并自动填好你的 Wi-Fi 和登录页面设置。"),
    ("share_link", "Share Setup Link", "Kongsi Pautan Tetapan", "分享设置链接"),
    ("share_footer", "Only the Wi-Fi name and login page settings are shared. Never your student ID or password.",
     "Hanya nama Wi-Fi dan tetapan halaman log masuk dikongsi. Tidak sekali-kali ID pelajar atau kata laluan anda.",
     "只会分享 Wi-Fi 名称和登录页面设置，绝不会分享你的学号或密码。"),
    ("share_paste", "Paste Setup Link", "Tampal Pautan Tetapan", "粘贴设置链接"),
    ("share_paste_invalid", "The clipboard doesn't contain a WiFi Connect setup link.",
     "Papan klip tidak mengandungi pautan tetapan WiFi Connect.", "剪贴板中没有 WiFi Connect 设置链接。"),
    ("import_title", "Use a classmate's setup?", "Guna tetapan rakan sekelas?", "使用同学的设置？"),
    ("import_message", "Wi-Fi: {0}. Login page: {1}. Your own student ID and password stay the same.",
     "Wi-Fi: {0}. Halaman log masuk: {1}. ID pelajar dan kata laluan anda sendiri kekal sama.",
     "Wi-Fi：{0}。登录页面：{1}。你自己的学号和密码保持不变。"),
    ("import_use", "Use Setup", "Guna Tetapan", "使用设置"),
    ("login_mode_manual", "set manually", "ditetapkan secara manual", "手动设置"),
    ("login_mode_auto", "automatic", "automatik", "自动"),
    ("qr_code", "QR code", "Kod QR", "二维码"),

    ("widget_description", "See if you're signed in, and sign in with one tap.",
     "Lihat sama ada anda telah log masuk, dan log masuk dengan satu ketikan.", "查看是否已登录，一键登录。"),
    ("widget_sign_in", "Sign In", "Log Masuk", "登录"),
    ("widget_tap_to_sign_in", "Tap Sign In on campus Wi-Fi.", "Ketik Log Masuk semasa di Wi-Fi kampus.",
     "连接校园 Wi-Fi 后点按“登录”。"),
    ("widget_signed_in_at", "Signed in at {0}", "Log masuk pada {0}", "{0} 已登录"),
    ("widget_set_up", "Set Up", "Sediakan", "设置"),
    ("widget_set_up_detail", "Open the app to add your student ID.", "Buka aplikasi untuk menambah ID pelajar anda.",
     "打开应用添加你的学号。"),
]

# Text only the iPhone app shows (Shortcuts guide, Face ID, widget, Siri).
IOS_ONLY = [
    (None, "Asks for {0} before showing Settings, where your password is saved.",
     "Meminta {0} sebelum menunjukkan Tetapan, tempat kata laluan anda disimpan.", "在显示保存密码的“设置”之前要求验证{0}。"),
    (None, "Choose **Wi-Fi**, tap **Network** and pick {0}.",
     "Pilih **Wi-Fi**, ketik **Rangkaian** dan pilih {0}.", "选择**无线局域网**，点按**网络**，然后选取 {0}。"),
    (None, "Clear History", "Kosongkan Sejarah", "清除记录"),
    (None, "Confirm it's you to change the app lock.", "Sahkan ini anda untuk menukar kunci aplikasi.", "请确认是你本人以更改应用锁。"),
    (None, "GET", "GET", "GET"),
    (None, "POST", "POST", "POST"),
    (None, "In the Shortcuts app", "Dalam aplikasi Pintasan", "在“快捷指令”App 中"),
    (None, "Join campus Wi-Fi first.", "Sertai Wi-Fi kampus dahulu.", "请先连接校园 Wi-Fi。"),
    (None, "Let your iPhone sign in for you every time you arrive on campus.",
     "Biarkan iPhone anda log masuk untuk anda setiap kali anda tiba di kampus.", "每次到达校园时，让 iPhone 自动为你登录。"),
    (None, "Log In", "Log Masuk", "登录"),
    (None, "Log In to Campus Wi-Fi", "Log Masuk ke Wi-Fi Kampus", "登录校园 Wi-Fi"),
    (None, "Logged in to campus Wi-Fi.", "Telah log masuk ke Wi-Fi kampus.", "已登录校园 Wi-Fi。"),
    (None, "No Sign-Ins Yet", "Belum Ada Log Masuk", "还没有登录记录"),
    (None, "No Wi-Fi", "Tiada Wi-Fi", "未连接 Wi-Fi"),
    (None, "Open Shortcuts", "Buka Pintasan", "打开快捷指令"),
    (None, "Opens WiFi Connect and signs in to the campus Wi-Fi.",
     "Membuka WiFi Connect dan log masuk ke Wi-Fi kampus.", "打开 WiFi Connect 并登录校园 Wi-Fi。"),
    (None, "Opens WiFi Connect and signs in.", "Membuka WiFi Connect dan log masuk.", "打开 WiFi Connect 并登录。"),
    (None, "Passcode", "Kod Laluan", "密码"),
    (None, "Require {0}", "Perlukan {0}", "需要{0}"),
    (None, "Saved in your iPhone's Keychain and only sent to your school's login page.",
     "Disimpan dalam Rantai Kunci iPhone anda dan hanya dihantar ke halaman log masuk universiti anda.",
     "保存在 iPhone 的钥匙串中，只会发送到学校的登录页面。"),
    (None, "Select **Run Immediately**, then tap **Next**.",
     "Pilih **Jalankan Serta-merta**, kemudian ketik **Seterusnya**.", "选择**立即运行**，然后点按**下一步**。"),
    (None, "Shortcuts automation", "Automasi Pintasan", "快捷指令自动化"),
    (None, "Sign In Needed", "Perlu Log Masuk", "需要登录"),
    (None, "Sign In to Campus Wi-Fi", "Log Masuk ke Wi-Fi Kampus", "登录校园 Wi-Fi"),
    (None, "Sign-ins will appear here, including automatic ones.",
     "Log masuk akan dipaparkan di sini, termasuk yang automatik.", "登录记录（包括自动登录）会显示在这里。"),
    (None, "Signs in to your school's Wi-Fi login page with your saved student ID and password.",
     "Log masuk ke halaman log masuk Wi-Fi universiti anda dengan ID pelajar dan kata laluan yang disimpan.",
     "使用已保存的学号和密码登录学校的 Wi-Fi 登录页面。"),
    (None, "Stay Signed In checks in the background and signs you back in if the campus Wi-Fi logs you out. iOS decides exactly when it runs. Notifications appear when the app signs you in on its own.",
     "Kekal Log Masuk menyemak di latar belakang dan melog masuk semula jika Wi-Fi kampus melog keluar anda. iOS menentukan bila ia dijalankan. Pemberitahuan dipaparkan apabila aplikasi melog masuk anda secara sendiri.",
     "“保持登录”会在后台检查，如果校园 Wi-Fi 让你退出登录，会自动重新登录。具体运行时间由 iOS 决定。应用自动为你登录时会显示通知。"),
    (None, "Tap **Automation**, then tap **+** (or **New Automation**).",
     "Ketik **Automasi**, kemudian ketik **+** (atau **Automasi Baharu**).", "点按**自动化**，然后点按**+**（或**新建自动化**）。"),
    (None, "Tap **Done**. That's it!", "Ketik **Selesai**. Itu sahaja!", "点按**完成**。大功告成！"),
    (None, "Tap **New Blank Automation**, search for **WiFi Connect** and add **Log In to Campus Wi-Fi**.",
     "Ketik **Automasi Kosong Baharu**, cari **WiFi Connect** dan tambah **Log Masuk ke Wi-Fi Kampus**.",
     "点按**新建空白自动化**，搜索 **WiFi Connect** 并添加**登录校园 Wi-Fi**。"),
    (None, "Tap to sign in to campus Wi-Fi.", "Ketik untuk log masuk ke Wi-Fi kampus.", "点按以登录校园 Wi-Fi。"),
    (None, "The Wi-Fi name you join on campus. Used in the auto-connect guide.",
     "Nama Wi-Fi yang anda sertai di kampus. Digunakan dalam panduan sambung automatik.", "你在校园里连接的 Wi-Fi 名称，用于自动连接指南。"),
    (None, "Tip", "Petua", "提示"),
    (None, "To stop the login page from popping up, open **Settings › Wi-Fi**, tap **ⓘ** next to {0} and turn off **Auto-Login**.",
     "Untuk menghentikan halaman log masuk daripada muncul, buka **Tetapan › Wi-Fi**, ketik **ⓘ** di sebelah {0} dan matikan **Log Masuk Auto**.",
     "要阻止登录页面弹出，请打开**设置 › 无线局域网**，点按 {0} 旁边的 **ⓘ**，然后关闭**自动登录**。"),
    (None, "Unlock to see your student ID and password.", "Buka kunci untuk melihat ID pelajar dan kata laluan anda.", "解锁以查看学号和密码。"),
    (None, "When you opened the app", "Semasa anda membuka aplikasi", "打开应用时"),
    (None, "Widget or Control Center", "Widget atau Pusat Kawalan", "小组件或控制中心"),
    (None, "You're online.", "Anda dalam talian.", "你已在线。"),
    (None, "Close and reopen WiFi Connect to use the new language.",
     "Tutup dan buka semula WiFi Connect untuk menggunakan bahasa baharu.", "关闭并重新打开 WiFi Connect 即可使用新语言。"),
    (None, "OK", "OK", "好"),
    (None, "your school", "universiti anda", "你的学校"),
    (None, "your school Wi-Fi", "Wi-Fi universiti anda", "学校的 Wi-Fi"),
]

_missing = sorted({row[1] for row in TABLE + IOS_ONLY} - MORE.keys())
if _missing:
    raise SystemExit("No Japanese or Tamil for:\n  " + "\n  ".join(_missing))
TABLE = [row + MORE[row[1]] for row in TABLE]
IOS_ONLY = [row + MORE[row[1]] for row in IOS_ONLY]

LANGUAGES = {"ms": 2, "zh": 3, "ja": 4, "ta": 5}


def android_format(text: str) -> str:
    """{0} → %1$s, {0:d} → %1$d, and escape for Android resources."""
    text = re.sub(r"\{(\d+):d\}", lambda m: f"%{int(m.group(1)) + 1}$d", text)
    text = re.sub(r"\{(\d+)\}", lambda m: f"%{int(m.group(1)) + 1}$s", text)
    text = text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    return text.replace("\\", "\\\\").replace("'", "\\'").replace('"', '\\"')


def write_android():
    res = ROOT / "android/app/src/main/res"
    for folder, column in (("values", 1), ("values-ms", 2), ("values-zh", 3), ("values-ja", 4), ("values-ta", 5)):
        lines = ['<?xml version="1.0" encoding="utf-8"?>',
                 "<!-- Generated by scripts/i18n.py. Edit the table there, not this file. -->",
                 "<resources>"]
        for row in TABLE:
            if row[0] is None:
                continue
            extra = ' translatable="false"' if row[0] == "app_name" and column == 1 else ""
            if row[0] == "app_name" and column != 1:
                continue
            lines.append(f'    <string name="{row[0]}"{extra}>{android_format(row[column])}</string>')
        lines.append("</resources>")
        path = res / folder / "strings.xml"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")



# ---- iOS ----

IOS_PATTERN = re.compile(
    r'(?:String\(localized:|Text\(|Button\(|Toggle\(|Label\(|Section\(|navigationTitle\(|Picker\('
    r'|ContentUnavailableView\(|LabeledField\(|title: |text: |TextField\(|SecureField\(|confirmationDialog\('
    r'|IntentDescription\(|LocalizedStringResource = |dialog: |configurationDisplayName\(|\.description\('
    r'|displayName\(|shortTitle: |accessibilityLabel\(|\.alert\()\s*"((?:[^"\\]|\\.)*)"'
)
INT_INTERPOLATIONS = {"pingMilliseconds", "number"}


def ios_key(literal: str) -> str:
    """Swift string literal → String Catalog key (interpolations become format specifiers)."""
    def spec(m):
        return "%lld" if m.group(1).strip() in INT_INTERPOLATIONS else "%@"
    key = re.sub(r"\\\(([^()]*(?:\([^()]*\))?[^()]*)\)", spec, literal)
    return key.replace('\\"', '"').replace("\\\\", "\\")


def ios_keys():
    keys = set()
    for path in (ROOT / "ios").rglob("*.swift"):
        for literal in IOS_PATTERN.findall(path.read_text(encoding="utf-8")):
            key = ios_key(literal)
            if re.sub(r"%(lld|@)", "", key).strip():
                keys.add(key)
    return keys


def table_by_english():
    def ios_format(text):
        text = re.sub(r"\{\d+:d\}", "%lld", text)
        return re.sub(r"\{\d+\}", "%@", text)
    result = {}
    for row in TABLE + IOS_ONLY:
        result[ios_format(row[1])] = {lang: ios_format(row[col]) for lang, col in LANGUAGES.items()}
    return result


def write_ios():
    known = table_by_english()
    keys = ios_keys()
    missing = sorted(k for k in keys if k not in known)
    if missing:
        raise SystemExit("No translation for these iOS strings:\n  " + "\n  ".join(missing))
    catalog = {"sourceLanguage": "en", "strings": {}, "version": "1.0"}
    for key in sorted(keys):
        catalog["strings"][key] = {
            "localizations": {
                ("zh-Hans" if lang == "zh" else lang): {
                    "stringUnit": {"state": "translated", "value": known[key][lang]}
                }
                for lang in LANGUAGES
            }
        }
    path = ROOT / "ios/Shared/Localizable.xcstrings"
    path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    write_android()
    write_ios()
    print("Android strings and iOS string catalog written.")
