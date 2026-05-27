# Inventory System

## Overview

A classic 28-slot inventory (OSRS-inspired) with equipment slots. Items stack based on their `max_stack` property. Equipment occupies named slots (head, body, legs, feet, main_hand, off_hand, ring, amulet).

## Current Implementation (V1)

### Server Tables

- `PlayerInventory`: owner, item_id, quantity, slot_index
- `PlayerEquipment`: owner, item_id, slot name

### Client Mirror

`InventorySystem` (`client/scripts/systems/inventory_system.gd`) maintains a local `slots` array and `equipment` dictionary. It syncs with the server when connected.

### Key Operations

| Operation | Server Reducer | Client Method |
|-----------|---------------|---------------|
| Add item | `add_item_to_inventory` | `add_item(item_id, qty)` |
| Remove item | — (not yet) | `remove_item(item_id, qty)` |
| Equip | `equip_item` | `equip_item(slot_index)` |
| Check has item | — | `has_item(item_id, qty)` |

### UI

`InventoryPanel` renders a 4-column grid of 28 buttons. Clicking an equippable item equips it. Toggle with `I` key.

## Enhancement Roadmap

### V2: Drag-and-Drop
- Implement drag-and-drop slot swapping
- Add item tooltips with full stat display
- Right-click context menu: equip, use, drop, examine

### V3: Banking and Trading
- Add `BankInventory` table with larger capacity
- Player-to-player trading interface
- Grand Exchange-style marketplace
