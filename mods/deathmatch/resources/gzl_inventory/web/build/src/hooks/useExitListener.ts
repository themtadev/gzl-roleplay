import { useEffect, useRef } from 'react';
import { noop } from '../utils/misc';
import { fetchNui } from '../utils/fetchNui';
import { closeTooltip } from '../store/tooltip';
import { useAppDispatch } from '../store';
import { closeContextMenu } from '../store/contextMenu';

type FrameVisibleSetter = (bool: boolean) => void;

const LISTENED_KEYS = ['Escape', 'Esc'];

// Basic hook to listen for key presses in NUI in order to exit
export const useExitListener = (visibleSetter: FrameVisibleSetter, visible: boolean) => {
  const setterRef = useRef<FrameVisibleSetter>(noop);
  const visibleRef = useRef(visible);
  visibleRef.current = visible;
  const dispatch = useAppDispatch();

  useEffect(() => {
    setterRef.current = visibleSetter;
  }, [visibleSetter]);

  useEffect(() => {
    const keyHandler = (e: KeyboardEvent) => {
      if (!visibleRef.current || e.repeat) return;
      if (
        e.key === 'Escape' ||
        e.code === 'Escape' ||
        e.keyCode === 27 ||
        e.which === 27 ||
        LISTENED_KEYS.includes(e.code) ||
        LISTENED_KEYS.includes(e.key)
      ) {
        visibleRef.current = false;
        setterRef.current(false);
        dispatch(closeTooltip());
        dispatch(closeContextMenu());
        fetchNui('exit');
      }
    };

    window.addEventListener('keydown', keyHandler);

    return () => {
      window.removeEventListener('keydown', keyHandler);
    };
  }, []);
};
