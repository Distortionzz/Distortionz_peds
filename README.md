# 🚇 Distortionz_peds Update Summary

## ✅ Latest Version

**Distortionz_peds** has been updated into a full **Qbox/Ox-compatible underground contact system** with custom Distortionz notification support.

---

## 🔄 Major Changes

### 🧱 Qbox / Ox Migration
- Converted menu system from `qb-menu` to `ox_lib` context menus.
- Converted input system from `qb-input` to `ox_lib` input dialogs.
- Removed dependency on `qb-menu`.
- Removed dependency on `qb-input`.
- Added support for:
  - `qbx_core`
  - `ox_lib`
  - `ox_inventory`

### 🔔 Distortionz Notify Integration
- Integrated full support for `distortionz_notify`.
- All script notifications now use the custom Distortionz notification UI.
- Added fallback to `ox_lib` notifications if `distortionz_notify` is not running.
- Supports custom notification types:
  - `primary`
  - `success`
  - `error`
  - `warning`
  - `info`
  - `cash`
  - `police`

### 🔊 Per-Status Notification Sounds
- Delivery payout uses the `cash` notification sound.
- Police alerts use the `police` notification sound.
- Errors, warnings, success messages, and info messages use their own status sounds through `distortionz_notify`.

---

## 🕵️ Underground Contact System

- Main underground contact ped spawns at configured location.
- Ped is invincible, frozen, and uses idle scenario animation.
- Interaction prompt appears near the contact.
- Contact menu displays:
  - Script version
  - Player reputation
  - Cooldown status
  - Mini Market
  - Suspicious Delivery
  - Cancel Delivery
  - Black Market
  - Street Work placeholder

---

## 💰 Mini Market

- Players can sell configured valuable items.
- Menu reads the player’s inventory before showing sell options.
- Items without inventory amount are disabled.
- Player can enter custom sell amount.
- Server validates:
  - Item exists
  - Amount is valid
  - Player has enough of the item
  - Sell cooldown is not active
- High-value sales can trigger police alerts.
- Selling items increases underground reputation.

---

## 📦 Suspicious Delivery System

- Players can request suspicious delivery jobs.
- Delivery jobs include:
  - Random delivery item
  - Random drop-off location
  - Delivery timer
  - Delivery cooldown
  - GPS route
  - Receiver ped at destination
- Delivery receiver ped:
  - Spawns at drop-off
  - Uses phone idle animation
  - Faces player during handoff
  - Plays handoff animation
  - Returns to phone animation after handoff
- Delivery can fail if:
  - Timer expires
  - Player dies
  - Player loses delivery item
  - Player is too far from drop-off
- Delivery completion increases reputation and pays the player.

---

## 🤝 Animation Improvements

- Main contact now performs handoff animation when giving a delivery item.
- Receiver ped performs handoff animation when taking the delivery item.
- Player and ped face each other before animation starts.
- Movement controls are disabled during handoff to prevent animation breaking.

---

## 📈 Reputation System

- Underground reputation is stored in player metadata.
- Rep increases from:
  - Selling items
  - Completing deliveries
  - Buying black market items
- Rep levels unlock better opportunities.
- Higher reputation gives payout bonuses.

Default reputation levels:

```txt
Unknown
Runner
Trusted
Plugged In
Heavy Mover
Underground VIP
