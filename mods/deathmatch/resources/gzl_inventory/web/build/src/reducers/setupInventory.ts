import { CaseReducer, PayloadAction } from '@reduxjs/toolkit';
import { getItemData, itemDurability } from '../helpers';
import { Items } from '../store/items';
import { Inventory, State } from '../typings';

export const setupInventoryReducer: CaseReducer<
  State,
  PayloadAction<{
    leftInventory?: Inventory;
    rightInventory?: Inventory;
  }>
> = (state, action) => {
  const { leftInventory, rightInventory } = action.payload;
  const curTime = Math.floor(Date.now() / 1000);

  // Index once instead of scanning all items for every slot (O(slots * items)).
  const indexItems = (inventory?: Inventory) => new Map(
    Object.values(inventory?.items || {}).filter(Boolean).map(item => [item.slot, item])
  );
  const leftItems = indexItems(leftInventory);
  const rightItems = indexItems(rightInventory);

  if (leftInventory)
    state.leftInventory = {
      ...leftInventory,
      items: Array.from(Array(leftInventory.slots), (_, index) => {
        const item = leftItems.get(index + 1) || {
          slot: index + 1,
        };

        if (!item.name) return item;

        if (typeof Items[item.name] === 'undefined') {
          Items[item.name] = {
            name: item.name,
            label: (item as any).label || item.name,
            stack: true,
            usable: true,
            close: true,
            count: item.count || 1,
          };
          getItemData(item.name);
        }

        item.durability = itemDurability(item.metadata, curTime);
        return item;
      }),
    };

  if (rightInventory)
    state.rightInventory = {
      ...rightInventory,
      items: Array.from(Array(rightInventory.slots), (_, index) => {
        const item = rightItems.get(index + 1) || {
          slot: index + 1,
        };

        if (!item.name) return item;

        if (typeof Items[item.name] === 'undefined') {
          Items[item.name] = {
            name: item.name,
            label: (item as any).label || item.name,
            stack: true,
            usable: true,
            close: true,
            count: item.count || 1,
          };
          getItemData(item.name);
        }

        item.durability = itemDurability(item.metadata, curTime);
        return item;
      }),
    };

  state.isBusy = false;
};
