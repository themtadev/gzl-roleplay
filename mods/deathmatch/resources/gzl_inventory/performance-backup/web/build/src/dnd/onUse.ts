import { store } from '../store';
import { fetchNui } from '../utils/fetchNui';
import { Slot } from '../typings';

export const onUse = (item: Slot, countOverride?: number) => {
  const {
    inventory: { itemAmount },
  } = store.getState();
  const count = countOverride !== undefined ? countOverride : (itemAmount > 0 ? itemAmount : 1);
  fetchNui('useItem', { slot: item.slot, count: count });
};

