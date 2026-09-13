import { canStack, findAvailableSlot, getTargetInventory, isSlotWithItem } from '../helpers';
import { validateMove } from '../thunks/validateItems';
import { store } from '../store';
import { DragSource, DropTarget, InventoryType, ItemData, SlotWithItem } from '../typings';
import { moveSlots, stackSlots, swapSlots } from '../store/inventory';
import { Items } from '../store/items';

export const onDrop = (source: DragSource, target?: DropTarget) => {
  const { inventory: state } = store.getState();

  const { sourceInventory, targetInventory } = getTargetInventory(state, source.inventory, target?.inventory);

  const sourceSlot = sourceInventory.items[source.item.slot - 1] as SlotWithItem;
  if (!sourceSlot || !sourceSlot.name) return console.error('Source slot not found');

  const sourceData: ItemData =
    Items[sourceSlot.name] ||
    Items[sourceSlot.name.toLowerCase()] ||
    Items[sourceSlot.name.toUpperCase()] || {
      name: sourceSlot.name,
      label: (sourceSlot as any).label || (sourceSlot.metadata && sourceSlot.metadata.label) || sourceSlot.name,
      stack: true,
      usable: true,
      close: true,
      count: sourceSlot.count || 1,
    };

  // If dragging from container slot
  if (sourceSlot.metadata?.container !== undefined) {
    // Prevent storing container in container
    if (targetInventory.type === InventoryType.CONTAINER)
      return console.log(`Cannot store container ${sourceSlot.name} inside another container`);

    // Prevent dragging of container slot when opened
    if (state.rightInventory.id === sourceSlot.metadata.container)
      return console.log(`Cannot move container ${sourceSlot.name} when opened`);
  }

  const targetSlot = target
    ? targetInventory.items[target.item.slot - 1]
    : findAvailableSlot(sourceSlot, sourceData, targetInventory.items);

  if (targetSlot === undefined) return console.error('Target slot undefined!');

  // If dropping on container slot when opened
  if (targetSlot.metadata?.container !== undefined && state.rightInventory.id === targetSlot.metadata.container)
    return console.log(`Cannot swap item ${sourceSlot.name} with container ${targetSlot.name} when opened`);

  const count =
    state.shiftPressed && (sourceSlot.count || 1) > 1 && sourceInventory.type !== 'shop'
      ? Math.floor((sourceSlot.count || 1) / 2)
      : state.itemAmount === 0 || state.itemAmount > (sourceSlot.count || 1)
      ? (sourceSlot.count || 1)
      : state.itemAmount;

  const data = {
    fromSlot: sourceSlot,
    toSlot: targetSlot,
    fromType: sourceInventory.type,
    toType: targetInventory.type,
    count: count,
  };

  store.dispatch(
    validateMove({
      ...data,
      fromSlot: sourceSlot.slot,
      toSlot: targetSlot.slot,
    })
  );

  isSlotWithItem(targetSlot, true)
    ? sourceData.stack && canStack(sourceSlot, targetSlot)
      ? store.dispatch(
          stackSlots({
            ...data,
            toSlot: targetSlot,
          })
        )
      : store.dispatch(
          swapSlots({
            ...data,
            toSlot: targetSlot,
          })
        )
    : store.dispatch(moveSlots(data));
};
