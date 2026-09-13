import React, { useEffect, useRef, useState } from 'react';
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
  const visibleRef = useRef(false);

  useEffect(() => () => {
    if (timerRef.current) clearTimeout(timerRef.current);
  }, []);

  useNuiEvent('toggleHotbar', (state: unknown) => {
    if (timerRef.current) {
      clearTimeout(timerRef.current);
      timerRef.current = null;
    }

    const visible = typeof state === 'boolean' ? state : !visibleRef.current;
    visibleRef.current = visible;
    setHotbarVisible(visible);
    if (!visible) return;
    // MTA owns the lifetime of explicit visibility requests. A second timer
    // here can expire before the native surface does and swallow the next TAB.
    if (typeof state === 'boolean') return;
    timerRef.current = setTimeout(() => {
      visibleRef.current = false;
      setHotbarVisible(false);
      timerRef.current = null;
    }, 3000);
  });

  return (
    <SlideUp in={hotbarVisible}>
      <div className="hotbar-container">
        {items.map((i) => (
          <div
            className="hotbar-item-slot"
            style={{
              backgroundImage: `url(${
                i?.name ? getItemUrl(i as SlotWithItem) : 'none'
              }`,
            }}
            key={`hotbar-${i.slot}`}
          >
            {isSlotWithItem(i) && (
              <div className="item-slot-wrapper">
                <div className="hotbar-slot-header-wrapper">
                  <div className="inventory-slot-number">{i.slot}</div>
                  {i.count && (
                    <div
                      className={`inventory-weight ${
                        i.name == 'money'
                          ? 'inventory-weight--money'
                          : 'inventory-weight--amount'
                      }`}
                    >
                      {i.count.toLocaleString('en-us') +
                        ` ${i.name == 'money' ? '$' : 'x'}`}
                    </div>
                  )}
                </div>
                <div>
                  <div className="inventory-slot-label-box mx-0.5 mb-0.5">
                    <div className="inventory-slot-label-text">
                      {i.metadata?.label
                        ? i.metadata.label
                        : Items[i.name]?.label || i.name}
                    </div>
                  </div>
                  {i?.durability !== void 0 && (
                    <WeightBar percent={i.durability} durability={!0} />
                  )}
                </div>
              </div>
            )}
          </div>
        ))}
      </div>
    </SlideUp>
  );
};
export default InventoryHotbar;
