# Installing WiFi Connect

WiFi Connect isn't on the App Store or Google Play, so you install it yourself. GitHub builds both versions automatically. You download the file and put it on your phone.

- [Android](#android): about 5 minutes, nothing else needed.
- [iPhone](#iphone): about 15 minutes the first time, using a Windows PC (or a Mac) and a USB cable.

After installing, follow [First-time setup](#first-time-setup).

---

## Download the app file from GitHub

Both platforms start here. You need to be signed in to GitHub.

1. Open this repository on GitHub and click the **Actions** tab at the top.
2. In the left sidebar, click **Build Android app** or **Build iPhone app**.
3. Click the newest run in the list that has a green tick ✅.
4. Scroll to the bottom of the page. Under **Artifacts**, click:
   - **WifiConnect-apk** for Android, or
   - **WifiConnect-ipa** for iPhone.
5. GitHub always downloads artifacts as a `.zip`. Unzip it to get `WifiConnect.apk` or `WifiConnect.ipa`.

> **No artifacts, or "expired"?** GitHub deletes build files after 90 days. To make a fresh one, go to **Actions**, choose the workflow in the sidebar, click **Run workflow**, pick the branch and click the green **Run workflow** button. It's ready in about 2–3 minutes.

---

## Android

**You need:** Android 9 or later.

### 1. Get the APK onto your phone

Do one of these:

- **On the phone:** open GitHub in Chrome, sign in, and follow [Download the app file](#download-the-app-file-from-github). Then open **Files** (or **My Files** on Samsung), find the downloaded `.zip` in **Downloads**, tap it and choose **Extract**.
- **From your laptop:** download and unzip on Windows, then copy `WifiConnect.apk` to the phone. You can use a USB cable (choose **File transfer** on the phone), Google Drive, Telegram "Saved Messages", or email it to yourself.

### 2. Allow the install

Android blocks apps from outside the Play Store until you allow the app you're installing from.

1. Tap `WifiConnect.apk`.
2. If you see **"For your security, your phone is not allowed to install unknown apps from this source"**, tap **Settings**, turn on **Allow from this source**, then press back.
   - You can also find this switch under **Settings › Apps › Special app access › Install unknown apps**. On Samsung it's **Settings › Apps › ⋮ › Special access › Install unknown apps**. Choose the app you're opening the APK with, such as Files or Chrome.
3. Tap **Install**.
4. If **Google Play Protect** says the app is unrecognised or unsafe, tap **More details › Install anyway**. It warns about any app that isn't from the Play Store. WiFi Connect only talks to your campus login page, and you can read every line of its code in this repository.
5. Tap **Open**.

### 3. Keep automatic sign-in working

Android signs you in in the background, even when the app is closed. Some phone brands stop background apps to save battery, so do this once:

1. Go to **Settings › Apps › WiFi Connect › Battery** and choose **Unrestricted** (or **Don't optimise**).
2. **Xiaomi / Redmi / POCO:** also go to **Settings › Apps › Manage apps › WiFi Connect** and turn on **Autostart**.
3. **Huawei / Honor:** go to **Settings › Battery › App launch**, find WiFi Connect, switch to **Manage manually** and turn everything on.
4. **OPPO / realme / vivo:** go to **Settings › Battery**, find WiFi Connect and allow **Background activity** and **Auto launch**.

### Updating on Android

Each GitHub build is signed with a different key. Android therefore refuses to install a new version over the old one, showing **"App not installed"** or **"package conflicts with an existing package"**.

1. Uninstall WiFi Connect: long-press the icon › **App info** › **Uninstall**.
2. Install the new APK as above.
3. Enter your student ID and password again.

### Android troubleshooting

| Problem | Fix |
| --- | --- |
| "There was a problem parsing the package" | The download is incomplete, or you opened the `.zip` instead of the `.apk`. Download again and extract it. |
| "App not installed" | Uninstall the old version first (see [Updating](#updating-on-android)). Also check you have free storage space. |
| The install button is greyed out | A screen overlay is blocking it, such as a blue-light filter or chat bubbles. Turn the overlay off, then try again. |
| It doesn't sign in automatically | Check that **Sign In Automatically** is on in the app's Settings, and do [step 3](#3-keep-automatic-sign-in-working). Opening the app always signs in, as a fallback. |
| No "Signed in" notification | Go to **Settings › Apps › WiFi Connect › Notifications** and turn them on. |

---

## iPhone

**You need:**

- An iPhone on **iOS 17 or later**.
- A **Windows 10/11 PC** and a **USB cable** for your iPhone. A Mac also works; see [With a Mac](#with-a-mac-instead).
- An **Apple ID**. A free one works. Some people use a second Apple ID just for sideloading, but your normal one is fine.

Apple only allows App Store apps unless you sign the app yourself. **Sideloadly** does that for you using your Apple ID.

### 1. Install the tools on your PC (first time only)

1. **Uninstall** iTunes and iCloud if you installed them from the **Microsoft Store**. Sideloadly needs the versions from Apple's website.
2. Install **iTunes for Windows (64-bit)** from Apple's website: [apple.com/itunes](https://www.apple.com/itunes/). Scroll to "Looking for other versions?" and choose the Windows download, **not** the Microsoft Store link.
3. Install **iCloud for Windows** from Apple's website (support.apple.com, search "iCloud for Windows download"), again **not** from the Microsoft Store.
4. Install **Sideloadly** from [sideloadly.io](https://sideloadly.io).
5. Restart your PC.

### 2. Connect your iPhone

1. Plug the iPhone into the PC with the USB cable.
2. Unlock the iPhone. When it asks **"Trust This Computer?"**, tap **Trust** and enter your passcode.
3. Open iTunes once and check that your iPhone appears (a small phone icon at the top left). Then you can close iTunes.

### 3. Install the app with Sideloadly

1. Get `WifiConnect.ipa` (see [Download the app file](#download-the-app-file-from-github)).
2. Open **Sideloadly**.
3. Your iPhone should appear in the **iDevice** box. If not, unplug and replug it, unlock it and tap **Trust** again.
4. Drag `WifiConnect.ipa` onto the IPA icon at the top left of Sideloadly.
5. Type your **Apple ID email** in the **Apple account** box.
6. Click **Start**.
7. Enter your **Apple ID password** when asked, then the **6-digit verification code** that appears on your Apple devices. Sideloadly sends these only to Apple, to sign the app.
8. Wait for **Done** at the bottom of Sideloadly. This takes about 1–2 minutes.

### 4. Allow the app on your iPhone (first time only)

1. **Turn on Developer Mode.** This is required since iOS 16.
   1. Go to **Settings › Privacy & Security**, scroll to the bottom and tap **Developer Mode**. It only appears after you've installed a sideloaded app.
   2. Turn it on and tap **Restart**.
   3. After the restart, tap **Turn On** in the alert and enter your passcode.
2. **Trust your Apple ID as a developer.**
   1. Go to **Settings › General › VPN & Device Management**.
   2. Under **Developer App**, tap your Apple ID email.
   3. Tap **Trust "your email"**, then **Trust**.
3. Open **WiFi Connect** from the Home Screen.

### 5. Renew it every 7 days (free Apple ID)

With a free Apple ID, Apple lets sideloaded apps run for **7 days**. After that the app won't open, and you'll see "WiFi Connect is no longer available". Nothing is lost when this happens.

- **To renew manually:** plug in your iPhone and repeat [step 3](#3-install-the-app-with-sideloadly) with the same Apple ID. Your student ID, password and settings are kept.
- **To renew automatically:** in Sideloadly's options, turn on automatic refresh. Then leave Sideloadly running on your PC; it renews the app over Wi-Fi when your iPhone is on the same network. Check Sideloadly's site for the current steps.
- **To avoid renewing:** with a paid Apple Developer account ($99/year), the app lasts a year.

> Free Apple IDs can have at most **3 sideloaded apps** at once, and register up to **10 app IDs per week**.

### Updating on iPhone

Install the new `WifiConnect.ipa` with Sideloadly using the **same Apple ID**. It replaces the old version and keeps your settings.

### With a Mac instead

1. Install **Xcode 16 or later** from the Mac App Store.
2. Open `ios/WifiConnect.xcodeproj`.
3. Click the **WifiConnect** project, then the **WifiConnect** target, then **Signing & Capabilities**:
   - **Team:** click **Add Account…**, sign in with your Apple ID and pick it.
   - **Bundle Identifier:** change `com.yourname.WifiConnect` to something unique, like `com.yourname123.WifiConnect`.
4. Plug in your iPhone, select it at the top of the Xcode window and press **Run** (▶).
5. Do [step 4](#4-allow-the-app-on-your-iphone-first-time-only) on the iPhone.

The same 7-day limit applies with a free Apple ID. Press **Run** again to renew.

### iPhone troubleshooting

| Problem | Fix |
| --- | --- |
| Sideloadly doesn't see the iPhone | Use a data cable (not charge-only). Unlock the phone and tap **Trust**. Reinstall iTunes from apple.com, not the Microsoft Store. |
| "Guru Meditation" or "Your session has expired" | Apple's sign-in timed out. Click **Start** again. |
| "Maximum number of apps" or "You have reached the limit" | Free Apple IDs allow 3 sideloaded apps. Delete one you don't use, or use another Apple ID. |
| "Untrusted Developer" when opening the app | Do [step 4](#4-allow-the-app-on-your-iphone-first-time-only), part 2. |
| "Developer Mode required" | Do [step 4](#4-allow-the-app-on-your-iphone-first-time-only), part 1. |
| "WiFi Connect is no longer available" | The 7 days are up. [Renew it](#5-renew-it-every-7-days-free-apple-id). |
| The Shortcuts action is missing | Open WiFi Connect once after installing, then search Shortcuts for "WiFi Connect". |

---

## First-time setup

These steps are the same on both phones.

1. Open **WiFi Connect**.
2. Enter your **Student ID** and **Password**. They're stored encrypted on your phone (Keychain on iPhone, Android Keystore on Android) and are only sent to your school's login page.
3. Check that **School Wi-Fi** says `utarwifi` (it's the default).
4. Android only: allow **notifications** when asked, so it can tell you when it has signed you in.
5. On campus, join `utarwifi` and tap **Connect**. You should see **Connected**.

### Make it automatic

- **Android:** nothing to do. **Sign In Automatically** is on by default, and the app signs in whenever your phone joins a Wi-Fi network with a login page.
- **iPhone:** set up a Shortcuts automation once. In the app, tap **Auto Sign-In › Set Up** for the guide, or:
  1. Open **Shortcuts › Automation › +** (or **New Automation**).
  2. Choose **Wi-Fi**, tap **Network**, pick `utarwifi`, then select **Run Immediately** and tap **Next**.
  3. Tap **New Blank Automation**, search for **WiFi Connect** and add **Log In to Campus Wi-Fi**.
  4. Tap **Done**.

**Optional (iPhone):** to stop iOS's own login page from popping up as well, go to **Settings › Wi-Fi**, tap **ⓘ** next to `utarwifi` and turn off **Auto-Login**.

If it doesn't sign in, see [If automatic detection doesn't work](../README.md#if-automatic-detection-doesnt-work) in the README.

## Uninstalling

- **Android:** long-press the icon › **App info** › **Uninstall**.
- **iPhone:** long-press the icon › **Remove App** › **Delete App**. You can also delete the Shortcuts automation, and remove your Apple ID under **Settings › General › VPN & Device Management** if you no longer sideload anything.
