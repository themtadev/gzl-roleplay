import React, { useState, useEffect } from 'react';
import { useDragLayer, useDragDropManager } from 'react-dnd';
import { DragSource } from '../../typings';

const DragPreview: React.FC = () => {
  const { data, isDragging } = useDragLayer((monitor) => ({
    data: monitor.getItem() as DragSource & { label?: string },
    isDragging: monitor.isDragging(),
  }));

  const manager = useDragDropManager();
  const previewRef = React.useRef<HTMLDivElement>(null);
  React.useLayoutEffect(() => {
    if (!isDragging) return;
    const monitor = manager.getMonitor();
    let frame: number | null = null;
    const paint = () => {
      frame = null;
      const offset = monitor.getSourceClientOffset();
      if (previewRef.current && offset) {
        previewRef.current.style.transform = 'translate3d(' + Math.round(offset.x) + 'px,' + Math.round(offset.y) + 'px,0)';
      }
    };
    paint();
    const unsubscribe = monitor.subscribeToOffsetChange(() => {
      if (frame === null) frame = requestAnimationFrame(paint);
    });
    return () => { unsubscribe(); if (frame !== null) cancelAnimationFrame(frame); };
  }, [manager, isDragging]);

  const [imgFailed, setImgFailed] = useState(false);

  useEffect(() => {
    setImgFailed(false);
  }, [data?.image]);

  const { hasImage, rawUrl, displayName } = React.useMemo(() => {
    if (!data || !data.item) return { hasImage: false, rawUrl: '', displayName: '' };
    const hasImg = Boolean(data.image && data.image !== 'url("")' && data.image !== 'none' && data.image !== 'url("none")');
    const url = hasImg ? data.image!.replace(/^url\(["']?/, '').replace(/["']?\)$/, '') : '';
    const name = (data as any).label || data.item.name;
    return { hasImage: hasImg, rawUrl: url, displayName: name };
  }, [data]);

  if (!isDragging || !data || !data.item) {
    return null;
  }

  return (
    <div
      ref={previewRef}
      className="item-drag-preview"
      style={{
        pointerEvents: 'none',
      }}
    >
      {hasImage && !imgFailed ? (
        <img
          src={rawUrl}
          alt=""
          style={{ width: '100%', height: '100%', objectFit: 'contain' }}
          onError={() => setImgFailed(true)}
        />
      ) : (
        <div
          style={{
            width: '100%',
            height: '100%',
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            justifyContent: 'center',
            backgroundColor: '#1e293b',
            border: '2px solid #38bdf8',
            borderRadius: '8px',
            color: '#ffffff',
            fontSize: '11px',
            fontWeight: 700,
            padding: '4px',
            textAlign: 'center',
            boxShadow: '0 4px 12px rgba(0,0,0,0.5)',
          }}
        >
          <svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#38bdf8" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" style={{ marginBottom: '2px' }}>
            <path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z" />
            <polyline points="3.27 6.96 12 12.01 20.73 6.96" />
            <line x1="12" y1="22.08" x2="12" y2="12" />
          </svg>
          <span style={{ maxWidth: '100%', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
            {displayName}
          </span>
        </div>
      )}
    </div>
  );
};

export default React.memo(DragPreview);
