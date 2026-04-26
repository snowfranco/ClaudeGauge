# ClaudeGauge 🟢

A lightweight macOS app that shows your Claude.ai usage in real time — right on your screen.
<img width="329" height="242" alt="Screenshot 2026-04-25 at 6 05 08 PM" src="https://github.com/user-attachments/assets/39eb87c0-9497-4985-b983-99a31fd61473" />
<img width="124" height="66" alt="Screenshot 2026-04-25 at 6 05 16 PM" src="https://github.com/user-attachments/assets/5c840361-40e6-430a-833b-d5a98c12cd9d" />


---

## ✨ What It Does

- Floating widget that stays visible while you work  
- Color-coded usage indicator (green → red)  
- Hover to expand: see % used, status, and insights  
- Optional live sync with Claude.ai  
- Launch at login support  
- Subtle alert sounds when usage increases  

---

## 🎯 Color Guide

| Color | Range | Meaning |
|------|------|--------|
| 🟢 Green | 0–39% | Work freely |
| 🟡 Yellow | 40–69% | Consider starting a new conversation |
| 🟠 Orange | 70–84% | Wrap up or switch models |
| 🔴 Red | 85–100% | Start fresh or wait for recovery |

---

## 🚀 Download

👉 Get the latest version here:  
https://github.com/snowfranco/ClaudeGauge/releases

### First-time launch

ClaudeGauge is not notarized yet.

If macOS blocks the app:
1. Right-click `ClaudeGauge.app`  
2. Click **Open**  
3. Click **Open** again  

---

## 🔗 Connect Live Usage (Optional)

To sync with your real Claude usage:

1. Open claude.ai and log in  
2. Open DevTools (`⌘ + Option + I`)  
3. Go to **Application → Cookies → https://claude.ai**  
4. Copy `sessionKey` value  
5. Paste into ClaudeGauge Settings  

---

## 🧪 Demo Mode

Use the manual slider in Settings to preview all usage states without connecting your account.

---

## 📦 Project Structure

ClaudeGauge/
- ClaudeGaugeApp.swift  
- AppDelegate.swift  
- UsageStore.swift  
- FloatingWidgetView.swift  
- SettingsView.swift  
- Extensions.swift  
- Info.plist  

---

## 🧠 Notes

- Data stays local — only sent to claude.ai  
- Session cookie is stored locally and can be refreshed anytime  
- Works without login using demo mode  

---
##Get Notifications on your phone when your Usage limit resets
On your iPhone
1. Download Pushcut from the App Store if you don't have it
2. Open Pushcut → tap Notifications → tap + to create a new one
3. Name it something clear, e.g. Claude Reset
4. Optionally customize the message body, e.g. "Your Claude usage window has reset — you're good to go"
5. Tap into the notification → find the Webhook URL and copy it. It'll look like https://api.pushcut.io/abc123xyz/notifications/Claude%20Reset


In ClaudeGauge (Settings)
1. Open the widget settings
2. Scroll to the new iPhone Notification section
3. Paste the webhook URL into the text field
4. Tap Send Test — your iPhone (and Watch if paired) should buzz within a few seconds
5. If it fires, you're set

---

## 🔮 Roadmap

- Custom alert sound settings  
- Usage history graph  
- Time-to-recovery estimates  
- Smart usage recommendations  
- Themes
- In-app notifications
