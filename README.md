# WiFi Connect

A small app for **iPhone and Android** that signs you in to your school's Wi-Fi login page with your student ID and password, so you don't have to type them every time you get to campus.

- **One tap:** open the app and tap **Connect**. Opening the app also tries to sign in on its own.
- **Fully automatic:** on Android the app signs in by itself whenever you join the school Wi-Fi. On iPhone you set up a Shortcuts automation once.
- **Private:** your student ID and password are stored encrypted on your phone and are only sent to your school's login page.
- **Simple design:** a clean, Apple-style layout on both phones, with Dark Mode support.

| | iPhone | Android |
| --- | --- | --- |
| Main screen | <img src="screenshots/ios-2-connected.png" width="220"> | <img src="screenshots/android-2-connected.png" width="220"> |
| Settings | <img src="screenshots/ios-3-settings.png" width="220"> | <img src="screenshots/android-3-settings.png" width="220"> |

Requires iOS 17 or later, or Android 9 or later.

## Install it on Android

1. On GitHub, open this repository's **Actions** tab and click the newest **Build Android app** run with a green tick ✅.
2. Under **Artifacts**, download **WifiConnect-apk** and unzip it to get `WifiConnect.apk`. Copy it to your phone, or download it on the phone directly.
3. Open `WifiConnect.apk` on your phone. If Android asks, allow your browser or file manager to **install unknown apps**, then tap **Install**.
4. Open **WiFi Connect**, enter your student ID and password, and allow notifications so it can tell you when it has signed you in.

That's it. **Sign In Automatically** is on by default, so the next time your phone joins the school Wi-Fi, it signs in by itself, even if the app is closed.

> Each new build is signed with a different key. To update the app, uninstall the old version first.

## Install it on iPhone (no Mac needed)

GitHub builds the app for you on one of its Macs, and you install it from a Windows PC with **Sideloadly**.

### 1. Download the app file

1. On GitHub, open this repository and click the **Actions** tab.
2. Click the newest **Build iPhone app** run with a green tick ✅.
3. At the bottom of the page, under **Artifacts**, click **WifiConnect-ipa**.
4. Unzip the download. You'll get `WifiConnect.ipa`.

To build again, open **Actions** › **Build iPhone app** › **Run workflow**.

### 2. Install it with Sideloadly (Windows)

1. Install **iTunes** and **iCloud** from apple.com (use the website versions, not the Microsoft Store ones). Sideloadly needs them to talk to your iPhone.
2. Download and install **Sideloadly** from [sideloadly.io](https://sideloadly.io).
3. Connect your iPhone with a USB cable. Unlock it and tap **Trust** when it asks about the computer.
4. Open Sideloadly, drag `WifiConnect.ipa` onto it, type your Apple ID email and click **Start**. Then enter your Apple ID password and any verification code. A free Apple ID works.
5. On your iPhone:
   - Go to **Settings › General › VPN & Device Management**, tap your Apple ID and tap **Trust**.
   - Go to **Settings › Privacy & Security › Developer Mode**, turn it on and restart when asked.

> With a free Apple ID the app stops opening after **7 days**. Repeat step 4 to renew it, which keeps your settings. Sideloadly can also renew it automatically over Wi-Fi while your PC is on. A paid Apple Developer account lasts a year.

### Have a Mac instead?

Open `ios/WifiConnect.xcodeproj` in Xcode 16 or later. Under **Signing & Capabilities**, pick your Apple ID as the **Team** and change the **Bundle Identifier** to something unique. Then select your iPhone and press **Run**.

## iPhone alternative with nothing to install: a Shortcuts automation

If you'd rather not install anything, the Shortcuts app can send the login form by itself. This works for most simple login pages, but not ones that add a new security token each time. It also stores your password in the shortcut as plain text.

**Find the login details on your Windows laptop (once, on campus):**

1. Join the school Wi-Fi on your laptop. The login page should open in Chrome or Edge. If it doesn't, go to `http://neverssl.com`.
2. Press **F12**, open the **Network** tab and tick **Preserve log**.
3. Log in as usual. In the list, click the first request whose **Method** is `POST`, usually named something like `login`.
4. Write down the **Request URL** from **Headers**. Then open **Payload** and write down every field name and value, such as `username`, `password` or `submit`.

**Create the automation on your iPhone:**

1. Open **Shortcuts** › **Automation** › **+** › **Wi-Fi**, pick the school network and select **Run Immediately**. Tap **Next**, then **New Blank Automation**.
2. Add the action **Get Contents of URL** and paste the Request URL.
3. Tap **▸** (Show More) to expand it. Set **Method** to **POST** and **Request Body** to **Form**.
4. Add one field for each entry you wrote down. Use your student ID and password for those two fields.
5. Tap **Done**. Next time you join the school Wi-Fi, your iPhone logs in by itself.

## Set it up on iPhone

1. Open **WiFi Connect** and enter your **student ID** and **password**.
2. Enter your school's **Wi-Fi name**. It's used in the setup guide.
3. On campus, join the school Wi-Fi and tap **Connect**.

### Sign in automatically

In the app, tap **Set Up Auto-Connect** for a step-by-step guide. In short:

1. Open **Shortcuts** › **Automation** › **+**.
2. Choose **Wi-Fi** and pick your school network, then select **Run Immediately**.
3. Add the action **Log In to Campus Wi-Fi** (from WiFi Connect).

To stop iOS from showing the login popup as well, go to **Settings › Wi-Fi**, tap **ⓘ** next to the school network and turn off **Auto-Login**.

## If automatic detection doesn't work

The app finds your school's login form the same way iOS does: it loads `captive.apple.com`, follows the redirect to the login page and fills in the form. Some portals build their login page entirely in JavaScript, and those need to be set up by hand:

1. Join the school Wi-Fi (don't sign in yet), open **Settings** in the app and tap **Detect Login Page**. If the form is found, the details are filled in for you.
2. Otherwise, turn on **Set Login Page Manually** and fill in:
   - **URL:** where the form is submitted.
   - **Method:** usually `POST`.
   - **ID Field / Password Field:** the `name` attributes of the student ID and password boxes.
   - **Extra fields:** any other `name=value` pairs the portal needs, one per line.

   To find these values, follow **Find the login details on your Windows laptop** above.

### What if my school Wi-Fi asks for my ID in a system popup, not a web page?

That's a WPA2/WPA3-Enterprise (802.1X) network, such as eduroam. iOS saves those credentials after you enter them once, and signs in automatically from then on, so you don't need this app. If iOS keeps asking, go to **Settings › Wi-Fi**, tap **ⓘ** › **Forget This Network**, then join again, enter your ID and password, and tap **Trust** when the certificate appears.

## Project layout

| Path | Purpose |
| --- | --- |
| `ios/` | iPhone app (SwiftUI). `PortalLogin.swift` signs in, `HTMLForm.swift` reads the login page, and `LogInIntent.swift` adds the Shortcuts action. |
| `android/` | Android app (Kotlin + Jetpack Compose). `PortalLogin.kt` signs in, `HtmlForm.kt` reads the login page, and `AutoLogin.kt` signs in automatically when you join a network. |
| `.github/workflows/` | Builds the iPhone `.ipa` and Android `.apk`, and takes the screenshots. |
| `screenshots/` | Screenshots of both apps, taken automatically in the iOS simulator and Android emulator. |
