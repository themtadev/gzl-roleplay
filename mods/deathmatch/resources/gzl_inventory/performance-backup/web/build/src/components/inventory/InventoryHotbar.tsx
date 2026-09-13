import React, { useRef, useState } from 'react';
import { getItemUrl, isSlotWithItem } from '../../helpers';
import useNuiEvent from '../../hooks/useNuiEvent';
import { Items } from '../../store/items';
import WeightBar from '../utils/WeightBar';
import { useAppSelector } from '../../store';
import { selectLeftInventory } from '../../store/inventory';
import { SlotWithItem } from '../../typings';
import SlideUp from '../utils/transitions/SlideUp';

const InventoryHotbar: React.FC = () => {
  const [hotbarVisible, setHotbarVisible] = useState(false);
  const leftInventory = useAppSelector(selectLeftInventory);
  const items = (leftInventory?.items || []).slice(0, 5);
  const timerRef = useRef<any>(null);

  useNuiEvent('toggleHotbar', () => {
    if (timerRef.current) {
      clearTimeout(timerRef.current);
      timerRef.current = null;
    }

    setHotbarVisible(true);
    timerRef.current = setTimeout(() => {
      setHotbarVisible(false);
      timerRef.current = null;
    }, 3000);
  });

  return (
    <SlideUp in={hotbarVisible}>
      <div className="hotbar-container">
        {items.map((item) => {
          const hasItem = isSlotWithItem(item);
          const imageUrl = hasItem ? getItemUrl(item as SlotWithItem) : null;

          return (
            <div
              className="hotbar-item-slot"
              style={{
                backgroundImage: imageUrl ? `url("${imageUrl}")` : 'none',
              }}
              key={`hotbar-${item.slot}`}
            >
              {hasItem && (
                <div className="item-slot-wrapper">
                  <div className="hotbar-slot-header-wrapper">
                    <div className="inventory-slot-number">{item.slot}</div>
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
                    {item?.durability !== undefined && <WeightBar percent={item.durability} durability />}
                    <div className="inventory-slot-label-box">
                      <div className="inventory-slot-label-text">
                        {item.metadata?.label ? item.metadata.label : Items[item.name]?.label || item.name}
                      </div>
                    </div>
                  </div>
                </div>
              )}
            </div>
          );
        })}
      </div>
    </SlideUp>
  );
};

export default React.memo(InventoryHotbar);
