import { flip, FloatingPortal, offset, shift, useFloating, useTransitionStyles } from '@floating-ui/react';
import React, { useEffect, useRef, useCallback } from 'react';
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

  const rafIdRef = useRef<number | null>(null);
  const coordsRef = useRef<{ clientX: number; clientY: number }>({ clientX: 0, clientY: 0 });
  const refsRef = useRef(refs);
  refsRef.current = refs;

  const hoverDataRef = useRef(hoverData);
  hoverDataRef.current = hoverData;

  const applyPosition = useCallback((clientX: number, clientY: number) => {
    refsRef.current.setPositionReference({
      getBoundingClientRect() {
        return {
          width: 0,
          height: 0,
          x: clientX,
          y: clientY,
          left: clientX,
          top: clientY,
          right: clientX,
          bottom: clientY,
        };
      },
    });
  }, []);

  useEffect(() => {
    if (!hoverData.open) {
      if (rafIdRef.current !== null) {
        cancelAnimationFrame(rafIdRef.current);
        rafIdRef.current = null;
      }
      return;
    }

    const handleMouseMove = (event: MouseEvent) => {
      coordsRef.current = { clientX: event.clientX, clientY: event.clientY };

      if (rafIdRef.current === null) {
        rafIdRef.current = requestAnimationFrame(() => {
          rafIdRef.current = null;
          applyPosition(coordsRef.current.clientX, coordsRef.current.clientY);
        });
      }
    };

    if (coordsRef.current.clientX !== 0 || coordsRef.current.clientY !== 0) {
      applyPosition(coordsRef.current.clientX, coordsRef.current.clientY);
    }

    window.addEventListener('mousemove', handleMouseMove, { passive: true });

    return () => {
      window.removeEventListener('mousemove', handleMouseMove);
      if (rafIdRef.current !== null) {
        cancelAnimationFrame(rafIdRef.current);
        rafIdRef.current = null;
      }
    };
  }, [hoverData.open, applyPosition]);

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
