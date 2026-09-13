import { Inventory, InventoryType, ItemData, Slot, SlotWithItem, State } from '../typings';
import { isEqual } from 'lodash';
import { store } from '../store';
import { Items } from '../store/items';
import { imagepath } from '../store/imagepath';
import { fetchNui } from '../utils/fetchNui';

export const canPurchaseItem = (item: Slot, inventory: { type: Inventory['type']; groups: Inventory['groups'] }) => {
  if (inventory.type !== 'shop' || !isSlotWithItem(item)) return true;

  if (item.count !== undefined && item.count === 0) return false;

  if (item.grade === undefined || !inventory.groups) return true;

  const leftInventory = store.getState().inventory.leftInventory;

  // Shop requires groups but player has none
  if (!leftInventory.groups) return false;

  const reqGroups = Object.keys(inventory.groups);

  if (Array.isArray(item.grade)) {
    for (let i = 0; i < reqGroups.length; i++) {
      const reqGroup = reqGroups[i];

      if (leftInventory.groups[reqGroup] !== undefined) {
        const playerGrade = leftInventory.groups[reqGroup];
        for (let j = 0; j < item.grade.length; j++) {
          const reqGrade = item.grade[j];

          if (playerGrade === reqGrade) return true;
        }
      }
    }

    return false;
  } else {
    for (let i = 0; i < reqGroups.length; i++) {
      const reqGroup = reqGroups[i];
      if (leftInventory.groups[reqGroup] !== undefined) {
        const playerGrade = leftInventory.groups[reqGroup];

        if (playerGrade >= item.grade) return true;
      }
    }

    return false;
  }
};

export const canCraftItem = (item: Slot, inventoryType: string) => {
  if (!isSlotWithItem(item) || inventoryType !== 'crafting') return true;
  if (!item.ingredients) return true;
  const leftInventory = store.getState().inventory.leftInventory;
  const ingredientItems = Object.entries(item.ingredients);

  const remainingItems = ingredientItems.filter((ingredient) => {
    const [item, count] = [ingredient[0], ingredient[1]];
    const globalItem = Items[item];

    if (count >= 1) {
      if (globalItem && globalItem.count >= count) return false;
    }

    const hasItem = leftInventory.items.find((playerItem) => {
      if (isSlotWithItem(playerItem) && playerItem.name === item) {
        if (count < 1) {
          if (playerItem.metadata?.durability >= count * 100) return true;

          return false;
        }
      }
    });

    return !hasItem;
  });

  return remainingItems.length === 0;
};

export const isSlotWithItem = (slot: Slot, strict: boolean = false): slot is SlotWithItem => {
  if (!slot || slot.name === undefined || slot.name === '') return false;
  if (slot.weight === undefined) {
    slot.weight = 100;
  }
  if (slot.count === undefined) {
    slot.count = 1;
  }
  if (strict && slot.count <= 0) return false;
  return true;
};

export const canStack = (sourceSlot: Slot, targetSlot: Slot) =>
  sourceSlot.name === targetSlot.name && isEqual(sourceSlot.metadata, targetSlot.metadata);

export const findAvailableSlot = (item: Slot, data: ItemData, items: Slot[]) => {
  if (!data.stack) return items.find((target) => target.name === undefined);

  const stackableSlot = items.find((target) => target.name === item.name && isEqual(target.metadata, item.metadata));

  return stackableSlot || items.find((target) => target.name === undefined);
};

export const getTargetInventory = (
  state: State,
  sourceType: Inventory['type'],
  targetType?: Inventory['type']
): { sourceInventory: Inventory; targetInventory: Inventory } => ({
  sourceInventory: sourceType === InventoryType.PLAYER ? state.leftInventory : state.rightInventory,
  targetInventory: targetType
    ? targetType === InventoryType.PLAYER
      ? state.leftInventory
      : state.rightInventory
    : sourceType === InventoryType.PLAYER
    ? state.rightInventory
    : state.leftInventory,
});

export const itemDurability = (metadata: any, curTime: number) => {
  // sorry dunak
  // it's ok linden i fix inventory
  if (metadata?.durability === undefined) return;

  let durability = metadata.durability;

  if (durability > 100 && metadata.degrade)
    durability = ((metadata.durability - curTime) / (60 * metadata.degrade)) * 100;

  if (durability < 0) durability = 0;

  return durability;
};

export const getTotalWeight = (items: Inventory['items']) =>
  items.reduce((totalWeight, slot) => (isSlotWithItem(slot) ? totalWeight + slot.weight : totalWeight), 0);

export const isContainer = (inventory: Inventory) => inventory.type === InventoryType.CONTAINER;

export const getItemData = async (itemName: string) => {
  const resp: ItemData | null = await fetchNui('getItemData', itemName);

  if (resp?.name) {
    Items[itemName] = resp;
    return resp;
  }
};

export const getItemUrl = (item: string | SlotWithItem) => {
  const isObj = typeof item === 'object';

  if (isObj) {
    if (!item.name) return;

    const metadata = item.metadata;

    // @todo validate urls and support webp
    if (metadata?.imageurl) return `${metadata.imageurl}`;
    if (metadata?.image) {
      const img = metadata.image;
      if (img.startsWith('http://') || img.startsWith('https://') || img.startsWith('images/')) return img;
      return img.endsWith('.png') || img.endsWith('.svg') || img.endsWith('.webp') ? `${imagepath}/${img}` : `${imagepath}/${img}.png`;
    }
  }

  const itemName = isObj ? (item.name as string) : item;
  const itemData = Items[itemName] || Items[itemName.toLowerCase()] || Items[itemName.toUpperCase()];

  let rawImg: string | undefined = itemData?.client?.image || itemData?.image;

  if (!rawImg) {
    rawImg = `${itemName}.png`;
  }

  if (rawImg.startsWith('http://') || rawImg.startsWith('https://') || rawImg.startsWith('images/')) {
    return rawImg;
  }

  if (!rawImg.endsWith('.png') && !rawImg.endsWith('.svg') && !rawImg.endsWith('.webp') && !rawImg.endsWith('.jpg')) {
    rawImg = `${rawImg}.png`;
  }

  return `${imagepath}/${rawImg}`;
};

