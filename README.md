# WiFi Connect

A small iPhone app that signs you in to your school's Wi-Fi login page with your student ID and password, so you don't have to type them every time you get to campus.

- **One tap:** open the app and tap **Connect**. Opening the app also tries to sign in on its own.
- **Fully automatic:** set up a Shortcuts automation once and your iPhone signs in by itself every time it joins the school Wi-Fi.
- **Private:** your student ID and password are stored in the iPhone Keychain and are only sent to your school's login page.
- **Simple design:** built with SwiftUI and standard iOS controls, with support for Dark Mode and Dynamic Type.

Requires iOS 17 or later.

## Install it on your iPhone

Apple only lets you install apps from outside the App Store with Xcode, so you'll need a Mac once.

1. Install **Xcode 16** or later from the Mac App Store.
2. Download this repository and open `WifiConnect.xcodeproj`.
3. Select the **WifiConnect** project, then the **WifiConnect** target, then **Signing & Capabilities**:
   - **Team:** add your Apple ID and pick it. A free Apple ID works.
   - **Bundle Identifier:** change `com.yourname.WifiConnect` to something unique, like `com.janedoe.WifiConnect`.
4. Plug in your iPhone, select it at the top of Xcode and press **Run** (▶).
5. The first time, go to **Settings › General › VPN & Device Management** on your iPhone and trust your developer certificate. Also turn on **Settings › Privacy & Security › Developer Mode** if iOS asks you to.

> With a free Apple ID the app stops opening after 7 days. Press **Run** in Xcode again to renew it. A paid Apple Developer account lasts a year.

## Set it up

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

1. In **Settings**, join the school Wi-Fi (don't sign in yet) and tap **Detect Login Page**. If the form is found, the details are filled in for you.
2. Otherwise, turn on **Set Login Page Manually** and fill in:
   - **URL:** where the form is submitted.
   - **Method:** usually `POST`.
   - **ID Field / Password Field:** the `name` attributes of the student ID and password boxes.
   - **Extra fields:** any other `name=value` pairs the portal needs, one per line.

   To find these values, open the login page in Safari on a Mac (**Develop › Show Web Inspector**) and look at the `<form>` and its `<input>` elements, or at the request sent when you sign in from the **Network** tab.

### What if my school Wi-Fi asks for my ID in a system popup, not a web page?

That's a WPA2/WPA3-Enterprise (802.1X) network, such as eduroam. iOS saves those credentials after you enter them once, and signs in automatically from then on, so you don't need this app. If iOS keeps asking, go to **Settings › Wi-Fi**, tap **ⓘ** › **Forget This Network**, then join again, enter your ID and password, and tap **Trust** when the certificate appears.

## Project layout

| File | Purpose |
| --- | --- |
| `WifiConnect/ContentView.swift` | Main screen with the status indicator and Connect button |
| `WifiConnect/SettingsView.swift` | Account, Wi-Fi name and login page settings |
| `WifiConnect/AutomationGuideView.swift` | Shortcuts automation guide |
| `WifiConnect/PortalLogin.swift` | Detects the captive portal, submits the form and checks you're online |
| `WifiConnect/HTMLForm.swift` | Finds the login form and its fields in the portal's HTML |
| `WifiConnect/LogInIntent.swift` | The **Log In to Campus Wi-Fi** action for Shortcuts and Siri |
| `WifiConnect/Credentials.swift` | Keychain storage for the student ID and password |
