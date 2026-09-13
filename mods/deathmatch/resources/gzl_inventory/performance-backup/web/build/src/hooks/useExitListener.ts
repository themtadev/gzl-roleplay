import { useEffect, useRef } from 'react';
import { noop } from '../utils/misc';
import { fetchNui } from '../utils/fetchNui';
import { closeTooltip } from '../store/tooltip';
import { useAppDispatch } from '../store';
import { closeContextMenu } from '../store/contextMenu';

type FrameVisibleSetter = (bool: boolean) => void;

const LISTENED_KEYS = ['Escape', 'Esc'];

// Basic hook to listen for key presses in NUI in order to exit
export const useExitListener = (visibleSetter: FrameVisibleSetter) => {
  const setterRef = useRef<FrameVisibleSetter>(noop);
  const dispatch = useAppDispatch();

  useEffect(() => {
    setterRef.current = visibleSetter;
  }, [visibleSetter]);

  useEffect(() => {
    const keyHandler = (e: KeyboardEvent) => {
      if (
        e.key === 'Escape' ||
        e.code === 'Escape' ||
        e.keyCode === 27 ||
        e.which === 27 ||
        LISTENED_KEYS.includes(e.code) ||
        LISTENED_KEYS.includes(e.key)
      ) {
        setterRef.current(false);
        dispatch(closeTooltip());
        dispatch(closeContextMenu());
        fetchNui('exit');
      }
    };

    window.addEventListener('keyup', keyHandler);
    window.addEventListener('keydown', keyHandler);

    return () => {
      window.removeEventListener('keyup', keyHandler);
      window.removeEventListener('keydown', keyHandler);
    };
  }, []);
};
