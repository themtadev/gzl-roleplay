import { flip, FloatingPortal, offset, shift, useFloating, useTransitionStyles } from '@floating-ui/react';
import React, { useEffect } from 'react';
import { useAppSelector } from '../../store';
import SlotTooltip from '../inventory/SlotTooltip';

const Tooltip: React.FC = () => {
  const hoverData = useAppSelector((state) => state.tooltip);

  const { refs, context, floatingStyles } = useFloating({
    middleware: [flip(), shift(), offset({ mainAxis: 10, crossAxis: 10 })],
    open: hoverData.open,
    placement: 'right-start',
  });

  const { isMounted, styles } = useTransitionStyles(context, {
    duration: 200,
  });

  // Anchor to the hovered slot: no pointer listener, layout reads or React
  // commits on every mouse movement. Floating UI still handles screen edges.
  useEffect(() => {
    if (!hoverData.open || !hoverData.anchor) return;
    const { x, y } = hoverData.anchor;
    refs.setPositionReference({
      getBoundingClientRect: () => ({ x, y, left: x, right: x, top: y, bottom: y, width: 0, height: 0 }),
    });
  }, [hoverData.open, hoverData.anchor, refs]);

  return (
    <>
      {isMounted && hoverData.item && hoverData.inventoryType && (
        <FloatingPortal>
          <SlotTooltip
            ref={refs.setFloating}
            style={{ ...floatingStyles, ...styles }}
            item={hoverData.item!}
            inventoryType={hoverData.inventoryType!}
          />
        </FloatingPortal>
      )}
    </>
  );
};

export default Tooltip;
