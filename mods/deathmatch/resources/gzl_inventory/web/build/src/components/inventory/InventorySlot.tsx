import React, { useCallback, useMemo, useRef } from 'react';
import {
  DragSource,
  Inventory,
  InventoryType,
  Slot,
  SlotWithItem,
} from '../../typings';
import { useDrag, useDrop } from 'react-dnd';
import { useAppDispatch } from '../../store';
import WeightBar from '../utils/WeightBar';
import { onDrop } from '../../dnd/onDrop';
import { onBuy } from '../../dnd/onBuy';
import { Items } from '../../store/items';
import {
  canCraftItem,
  canPurchaseItem,
  getItemUrl,
  isSlotWithItem,
} from '../../helpers';
import { onUse } from '../../dnd/onUse';
import { Locale } from '../../store/locale';
import { onCraft } from '../../dnd/onCraft';
import { closeTooltip, openTooltip } from '../../store/tooltip';
import { openContextMenu } from '../../store/contextMenu';
import { useMergeRefs } from '@floating-ui/react';

const failedImages = new Set<string>();

interface SlotProps {
  inventoryId: Inventory['id'];
  inventoryType: Inventory['type'];
  inventoryGroups: Inventory['groups'];
  item: Slot;
}

const InventorySlot: React.ForwardRefRenderFunction<
  HTMLDivElement,
  SlotProps
> = ({ item, inventoryId, inventoryType, inventoryGroups }, ref) => {
  const dispatch = useAppDispatch();
  const timerRef = useRef<any>(null);

  React.useEffect(
    () => () => {
      if (timerRef.current) clearTimeout(timerRef.current);
    },
    [item]
  );

  const isPurchasable = useMemo(
    () =>
      canPurchaseItem(item, { type: inventoryType, groups: inventoryGroups }),
    [item, inventoryType, inventoryGroups]
  );
  const isCraftable = useMemo(
    () => canCraftItem(item, inventoryType),
    [item, inventoryType]
  );

  const canDrag = useCallback(() => {
    return isPurchasable && isCraftable;
  }, [isPurchasable, isCraftable]);

  const [{ isDragging }, drag] = useDrag<
    DragSource,
    void,
    { isDragging: boolean }
  >(
    () => ({
      type: 'SLOT',
      collect: (monitor) => ({
        isDragging: monitor.isDragging(),
      }),
      item: () => {
        if (timerRef.current) clearTimeout(timerRef.current);
        dispatch(closeTooltip());
        return isSlotWithItem(item, inventoryType !== InventoryType.SHOP)
          ? {
              inventory: inventoryType,
              item: {
                name: item.name,
                slot: item.slot,
              },
              image: item?.name
                ? `url("${getItemUrl(item) || ''}")`
                : undefined,
            }
          : null;
      },
      canDrag,
      // A drag must not leave a delayed tooltip over the drop target.
      end: () => dispatch(closeTooltip()),
    }),
    [inventoryType, item, canDrag]
  );

  const [{ isOver }, drop] = useDrop<DragSource, void, { isOver: boolean }>(
    () => ({
      accept: 'SLOT',
      collect: (monitor) => ({
        isOver: monitor.isOver(),
      }),
      drop: (source) => {
        dispatch(closeTooltip());
        switch (source.inventory) {
          case InventoryType.SHOP:
            onBuy(source, {
              inventory: inventoryType,
              item: { slot: item.slot },
            });
            break;
          case InventoryType.CRAFTING:
            onCraft(source, {
              inventory: inventoryType,
              item: { slot: item.slot },
            });
            break;
          default:
            onDrop(source, {
              inventory: inventoryType,
              item: { slot: item.slot },
            });
            break;
        }
      },
      canDrop: (source) =>
        (source.item.slot !== item.slot ||
          source.inventory !== inventoryType) &&
        inventoryType !== InventoryType.SHOP &&
        inventoryType !== InventoryType.CRAFTING,
    }),
    [inventoryType, item]
  );

  const connectRef = useCallback(
    (element: HTMLDivElement) => drag(drop(element)),
    [drag, drop]
  );

  const handleContext = useCallback(
    (event: React.MouseEvent<HTMLDivElement>) => {
      event.preventDefault();
      if (inventoryType !== 'player' || !isSlotWithItem(item)) return;
      dispatch(
        openContextMenu({
          item,
          coords: { x: event.clientX, y: event.clientY },
        })
      );
    },
    [inventoryType, item, dispatch]
  );

  const handleDoubleClick = useCallback(
    (event: React.MouseEvent<HTMLDivElement>) => {
      event.preventDefault();
      if (inventoryType === 'player' && isSlotWithItem(item)) {
        onUse(item);
      }
    },
    [inventoryType, item]
  );

  const handleClick = useCallback(
    (event: React.MouseEvent<HTMLDivElement>) => {
      dispatch(closeTooltip());
      if (timerRef.current) clearTimeout(timerRef.current);
      if (
        event.ctrlKey &&
        isSlotWithItem(item) &&
        inventoryType !== 'shop' &&
        inventoryType !== 'crafting'
      ) {
        onDrop({ item: item, inventory: inventoryType });
      } else if (
        event.altKey &&
        isSlotWithItem(item) &&
        inventoryType === 'player'
      ) {
        onUse(item);
      }
    },
    [item, inventoryType, dispatch]
  );

  const refs = useMergeRefs([connectRef, ref]);

  const hasItem = isSlotWithItem(item);
  const imageUrl = useMemo(
    () => (hasItem ? getItemUrl(item as SlotWithItem) : null),
    [hasItem, item]
  );
  const [imageError, setImageError] = React.useState<boolean>(() =>
    Boolean(imageUrl && failedImages.has(imageUrl))
  );

  React.useEffect(() => {
    if (!imageUrl) {
      setImageError(false);
      return;
    }
    if (failedImages.has(imageUrl)) {
      setImageError(true);
      return;
    }
    setImageError(false);

    // Asynchronous probe that never triggers cascading onLoad re-renders
    const probe = new Image();
    probe.onerror = () => {
      failedImages.add(imageUrl);
      setImageError(true);
    };
    probe.src = imageUrl;
    return () => {
      probe.onerror = null;
    };
  }, [imageUrl]);

  return (
    <div
      ref={refs}
      onContextMenu={handleContext}
      onDoubleClick={handleDoubleClick}
      onClick={handleClick}
      className={`inventory-slot ${!hasItem ? 'inventory-slot--empty' : ''}`}
      style={{
        opacity: isDragging ? 0.35 : !isPurchasable || !isCraftable ? 0.6 : 1.0,
        backgroundImage:
          imageUrl && !imageError ? `url("${imageUrl}")` : 'none',
        borderColor: isOver ? 'rgba(56, 189, 248, 0.8)' : undefined,
      }}
    >
      {hasItem && (
        <div
          className="item-slot-wrapper"
          onMouseEnter={(event) => {
            const { right: x, top: y } =
              event.currentTarget.getBoundingClientRect();
            if (timerRef.current) clearTimeout(timerRef.current);
            timerRef.current = setTimeout(() => {
              dispatch(
                openTooltip({
                  item: item,
                  inventoryType: inventoryType,
                  anchor: { x, y },
                })
              );
            }, 500);
          }}
          onMouseLeave={() => {
            dispatch(closeTooltip()),
              timerRef.current &&
                (clearTimeout(timerRef.current), (timerRef.current = null));
          }}
        >
          <div className="px-1 pt-1 flex items-start justify-between flex-wrap gap-1">
            {item.weight > 0 && (
              <span className="inventory-weight">
                {item.weight >= 1e3
                  ? `${(item.weight / 1e3).toLocaleString('en-us', {
                      maximumFractionDigits: 1,
                    })} kg `
                  : `${item.weight.toLocaleString('en-us', {
                      minimumFractionDigits: 0,
                      maximumFractionDigits: 1,
                    })} g `}
              </span>
            )}
            <div className="flex flex-col items-end gap-1">
              {inventoryType === 'shop' && item?.price !== void 0 && (
                <React.Fragment>
                  {item?.currency !== 'money' &&
                  item.currency !== 'black_money' &&
                  item.price > 0 &&
                  item.currency ? (
                    <div className="item-slot-currency-wrapper">
                      <img
                        src={item.currency ? getItemUrl(item.currency) : 'none'}
                        alt="item-image"
                        style={{
                          imageRendering: '-webkit-optimize-contrast',
                          height: 'auto',
                          width: '2vh',
                          backfaceVisibility: 'hidden',
                          transform: 'translateZ(0)',
                        }}
                      />
                      <p>{item.price.toLocaleString('en-us')}</p>
                    </div>
                  ) : (
                    <React.Fragment>
                      {item.price > 0 && (
                        <div
                          className={`item-slot-price-wrapper ${
                            item.currency === 'money' || !item.currency
                              ? 'text-green-400'
                              : 'text-red-400'
                          }`}
                        >
                          <p>
                            {Locale.$ || '$'}
                            {item.price.toLocaleString('en-us')}
                          </p>
                        </div>
                      )}
                    </React.Fragment>
                  )}
                </React.Fragment>
              )}
              {item.count && (
                <span
                  className={`inventory-weight ${
                    item.name == 'money'
                      ? 'inventory-weight--money'
                      : 'inventory-weight--amount'
                  }`}
                >
                  {item.count.toLocaleString('en-us') +
                    ` ${item.name == 'money' ? '$' : 'x'}`}
                </span>
              )}
            </div>
          </div>
          <div>
            <div className="px-0.5 pb-0.5 flex items-center justify-between flex-wrap gap-1">
              <div className="inventory-slot-label-box">
                <div className="inventory-slot-label-text">
                  {item.metadata?.label
                    ? item.metadata.label
                    : Items[item.name]?.label || item.name}
                </div>
              </div>
            </div>
            {inventoryType !== 'shop' && item?.durability !== void 0 && (
              <WeightBar percent={item.durability} durability={!0} />
            )}
          </div>
        </div>
      )}
    </div>
  );
};
export default React.memo(React.forwardRef(InventorySlot));
