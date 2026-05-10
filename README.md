# Distortionz Underground Contact (Peds)

> Custom Qbox/FiveM underground contact ped — sell valuables, run deliveries, build reputation, unlock black-market items, trigger police alerts.

![FiveM](https://img.shields.io/badge/FiveM-cerulean-yellow?style=flat-square&labelColor=181b20)
![Qbox](https://img.shields.io/badge/Qbox-required-red?style=flat-square&labelColor=dfb317)
![License](https://img.shields.io/badge/License-MIT-brightgreen?style=flat-square)
![Version](https://img.shields.io/github/v/release/Distortionzz/distortionz_peds?style=flat-square&color=d4aa62&label=version)

A custom Qbox/FiveM underground contact script built for roleplay servers. Adds an illegal contact ped where players can sell valuable items, run suspicious deliveries, build reputation, unlock black market items, and trigger police alerts.

---

## ✨ Features

### 🕵️ Underground Contact Ped
- Custom illegal contact ped
- Map blip support
- 3D interaction text
- Version displayed in menu
- Reputation displayed in menu

### 💰 Mini Market Sell System
- Sell valuables, electronics, cards, and rare goods
- Inventory-aware menu
- Shows how many items the player has
- Custom sell amount input
- Random payout ranges
- Reputation payout bonus
- Sell cooldown display

### 📦 Suspicious Delivery System
- Random delivery item
- Random drop-off location
- GPS route to delivery point
- Delivery timer
- Delivery cooldown display
- Cancel delivery option
- Fail delivery on death
- Fail delivery if time expires
- Server-side delivery validation

### 🤝 Handoff Animations
- Main underground contact gives package to player
- Delivery receiver takes package from player
- Player and ped face each other before handoff
- Receiver returns to phone animation after handoff

### 📱 Receiver Ped System
- Random receiver ped models
- Receiver waits at drop-off location
- Receiver uses phone idle animation
- Premium prompt above receiver’s head
- Red marker disabled for cleaner look

### 📈 Reputation System
- Underground rep stored in QBCore metadata
- Rep increases from selling, deliveries, and black market purchases
- Rep levels unlock better opportunities
- Higher rep gives better delivery payouts

### 🛒 Black Market
- Rep-locked item shop
- Buy underground tools and items
- Black market cooldown display
- Uses existing QBCore items where possible

### 🚔 Police Alert System
- Chance to alert police on:
  - Starting deliveries
  - Completing deliveries
  - Selling high-value items
  - Buying black market items
- Temporary police blips
- Supports police/sheriff jobs

### 🛡️ Anti-Exploit Protection
- Server validates item names
- Server validates delivery distance
- Server validates active delivery
- Server validates inventory item exists
- Cooldown protection
- Logs suspicious invalid item attempts

---

## 🧱 Dependencies

```txt
qb-core
qb-menu
qb-input