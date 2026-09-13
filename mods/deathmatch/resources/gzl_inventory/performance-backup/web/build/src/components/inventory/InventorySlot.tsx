import React, { useCallback, useMemo, useRef } from 'react';
import { DragSource, Inventory, InventoryType, Slot, SlotWithItem } from '../../typings';
import { useDrag, useDragDropManager, useDrop } from 'react-dnd';
import { useAppDispatch } from '../../store';
import WeightBar from '../utils/WeightBar';
import { onDrop } from '../../dnd/onDrop';
import { onBuy } from '../../dnd/onBuy';
import { Items } from '../../store/items';
import { canCraftItem, canPurchaseItem, getItemUrl, isSlotWithItem } from '../../helpers';
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

const InventorySlot: React.ForwardRefRenderFunction<HTMLDivElement, SlotProps> = (
  { item, inventoryId, inventoryType, inventoryGroups },
  ref
) => {
  const manager = useDragDropManager();
  const dispatch = useAppDispatch();
  const timerRef = useRef<any>(null);

  const isPurchasable = useMemo(
    () => canPurchaseItem(item, { type: inventoryType, groups: inventoryGroups }),
    [item, inventoryType, inventoryGroups]
  );
  const isCraftable = useMemo(
    () => canCraftItem(item, inventoryType),
    [item, inventoryType]
  );

  const canDrag = useCallback(() => {
    return isPurchasable && isCraftable;
  }, [isPurchasable, isCraftable]);

  const [{ isDragging }, drag] = useDrag<DragSource, void, { isDragging: boolean }>(
    () => ({
      type: 'SLOT',
      collect: (monitor) => ({
        isDragging: monitor.isDragging(),
      }),
      item: () =>
        isSlotWithItem(item, inventoryType !== InventoryType.SHOP)
          ? {
              inventory: inventoryType,
              item: {
                name: item.name,
                slot: item.slot,
              },
              image: item?.name ? `url("${getItemUrl(item) || ''}")` : undefined,
            }
          : null,
      canDrag,
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
            onBuy(source, { inventory: inventoryType, item: { slot: item.slot } });
            break;
          case InventoryType.CRAFTING:
            onCraft(source, { inventory: inventoryType, item: { slot: item.slot } });
            break;
          default:
            onDrop(source, { inventory: inventoryType, item: { slot: item.slot } });
            break;
        }
      },
      canDrop: (source) =>
        (source.item.slot !== item.slot || source.inventory !== inventoryType) &&
        inventoryType !== InventoryType.SHOP &&
        inventoryType !== InventoryType.CRAFTING,
    }),
    [inventoryType, item]
  );

  const connectRef = useCallback((element: HTMLDivElement) => drag(drop(element)), [drag, drop]);

  const handleContext = useCallback(
    (event: React.MouseEvent<HTMLDivElement>) => {
      event.preventDefault();
      if (inventoryType !== 'player' || !isSlotWithItem(item)) return;
      dispatch(openContextMenu({ item, coords: { x: event.clientX, y: event.clientY } }));
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
      if (event.ctrlKey && isSlotWithItem(item) && inventoryType !== 'shop' && inventoryType !== 'crafting') {
        onDrop({ item: item, inventory: inventoryType });
      } else if (event.altKey && isSlotWithItem(item) && inventoryType === 'player') {
        onUse(item);
      }
    },
    [item, inventoryType, dispatch]
  );

  const refs = useMergeRefs([connectRef, ref]);

  const hasItem = isSlotWithItem(item);
  const imageUrl = useMemo(() => (hasItem ? getItemUrl(item as SlotWithItem) : null), [hasItem, item]);
  const [imageError, setImageError] = React.useState<boolean>(() => Boolean(imageUrl && failedImages.has(imageUrl)));

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
        backgroundImage: imageUrl && !imageError ? `url("${imageUrl}")` : 'none',
        borderColor: isOver ? 'rgba(56, 189, 248, 0.8)' : undefined,
      }}
    >
      {hasItem && (
        <div
          className="item-slot-wrapper"
          onMouseEnter={() => {
            timerRef.current = setTimeout(() => {
              dispatch(openTooltip({ item, inventoryType }));
            }, 300);
          }}
          onMouseLeave={() => {
            dispatch(closeTooltip());
            if (timerRef.current) {
              clearTimeout(timerRef.current);
              timerRef.current = null;
            }
          }}
        >
          {(!imageUrl || imageError) && (
            <div
              style={{
                position: 'absolute',
                top: '40%',
                left: '50%',
                transform: 'translate(-50%, -50%)',
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                justifyContent: 'center',
                opacity: 0.75,
                pointerEvents: 'none',
              }}
            >
              <svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="#38bdf8" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
                <path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z" />
                <polyline points="3.27 6.96 12 12.01 20.73 6.96" />
                <line x1="12" y1="22.08" x2="12" y2="12" />
              </svg>
            </div>
          )}
          <div
            className={
              inventoryType === 'player' && item.slot <= 5 ? 'item-hotslot-header-wrapper' : 'item-slot-header-wrapper'
            }
          >
            {inventoryType === 'player' && item.slot <= 5 && <div className="inventory-slot-number">{item.slot}</div>}
            <div className="item-slot-info-wrapper">
              <p>
                {item.weight > 0
                  ? item.weight >= 1000
                    ? `${(item.weight / 1000).toLocaleString('en-us', {
                        minimumFractionDigits: 1,
                        maximumFractionDigits: 2,
                      })}kg `
                    : `${item.weight.toLocaleString('en-us', {
                        maximumFractionDigits: 0,
                      })}g `
                  : ''}
              </p>
              <p>{item.count ? item.count.toLocaleString('en-us') + `x` : ''}</p>
            </div>
          </div>
          <div>
            {inventoryType !== 'shop' && item?.durability !== undefined && (
              <WeightBar percent={item.durability} durability />
            )}
            {inventoryType === 'shop' && item?.price !== undefined && (
              <>
                {item?.currency !== 'money' && item.currency !== 'black_money' && item.price > 0 && item.currency ? (
                  <div className="item-slot-currency-wrapper">
                    <img
                      src={item.currency ? getItemUrl(item.currency) : 'none'}
                      alt="item-currency"
                      loading="lazy"
                      decoding="async"
                      style={{
                        imageRendering: '-webkit-optimize-contrast',
                        height: 'auto',
                        width: '2vh',
                      }}
                      onError={(e) => {
                        (e.target as HTMLElement).style.display = 'none';
                      }}
                    />
                    <p>{item.price.toLocaleString('en-us')}</p>
                  </div>
                ) : (
                  <>
                    {item.price > 0 && (
                      <div
                        className="item-slot-price-wrapper"
                        style={{ color: item.currency === 'money' || !item.currency ? '#4ade80' : '#f87171' }}
                      >
                        <p>
                          {Locale.$ || '$'}
                          {item.price.toLocaleString('en-us')}
                        </p>
                      </div>
                    )}
                  </>
                )}
              </>
            )}
            <div className="inventory-slot-label-box">
              <div className="inventory-slot-label-text">
                {item.metadata?.label ? item.metadata.label : (Items[item.name]?.label || Items[item.name?.toLowerCase()]?.label || Items[item.name?.toUpperCase()]?.label || (item as any).label || item.name)}
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default React.memo(React.forwardRef(InventorySlot));
