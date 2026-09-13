import React, { useState } from 'react';
import { useDrop } from 'react-dnd';
import { useAppDispatch, useAppSelector } from '../../store';
import { selectItemAmount, setItemAmount } from '../../store/inventory';
import { DragSource } from '../../typings';
import { onUse } from '../../dnd/onUse';
import { onGive } from '../../dnd/onGive';
import { fetchNui } from '../../utils/fetchNui';
import { Locale } from '../../store/locale';
import UsefulControls from './UsefulControls';

const InventoryControl: React.FC = () => {
  const itemAmount = useAppSelector(selectItemAmount);
  const dispatch = useAppDispatch();

  const [infoVisible, setInfoVisible] = useState(false);

  const [, use] = useDrop<DragSource, void, any>(() => ({
    accept: 'SLOT',
    drop: (source) => {
      source.inventory === 'player' && onUse(source.item);
    },
  }));

  const [, give] = useDrop<DragSource, void, any>(() => ({
    accept: 'SLOT',
    drop: (source) => {
      source.inventory === 'player' && onGive(source.item);
    },
  }));

  const [, dropToFloor] = useDrop<DragSource, void, any>(() => ({
    accept: 'SLOT',
    drop: (source) => {
      if (source.inventory === 'player' && source.item?.slot) {
        fetchNui('dropItem', { slot: source.item.slot, count: itemAmount || 1 });
      }
    },
  }));

  const inputHandler = (event: React.ChangeEvent<HTMLInputElement>) => {
    event.target.valueAsNumber =
      isNaN(event.target.valueAsNumber) || event.target.valueAsNumber < 0 ? 0 : Math.floor(event.target.valueAsNumber);
    dispatch(setItemAmount(event.target.valueAsNumber));
  };

  return (
    <>
      <UsefulControls infoVisible={infoVisible} setInfoVisible={setInfoVisible} />
      <div className="inventory-control flex items-center justify-center px-3">
        <div className="grid grid-cols-1 gap-2.5">
          <input
            className="w-28 2k:w-32 4k:w-40 px-1 py-2.5 2k:py-4 4k:py-6 2k:text-xl 4k:text-3xl bg-dark border-zinc-700 bg-opacity-80 rounded-md text-center mb-8 focus:outline-none hover:border-gray-500 border border-transparent focus:border-indigo-400 transition-colors duration-300"
            type="number"
            defaultValue={itemAmount}
            onChange={inputHandler}
            min={0}
          />
          <div className="flex items-center justify-between flex-col space-y-3">
            <button className="inventory-control__button inventory-control__button--use" ref={use} title="Kullan (Sürükle & Bırak)">
              <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" strokeWidth="2" stroke="currentColor" fill="none" strokeLinecap="round" strokeLinejoin="round">
                <path stroke="none" d="M0 0h24v24H0z" fill="none" />
                <path d="M8 11v-3.5a1.5 1.5 0 0 1 3 0v2.5" />
                <path d="M11 9.5v-3a1.5 1.5 0 0 1 3 0v3.5" />
                <path d="M14 7.5a1.5 1.5 0 0 1 3 0v2.5" />
                <path d="M17 9.5a1.5 1.5 0 0 1 3 0v4.5a6 6 0 0 1 -6 6h-2h.208a6 6 0 0 1 -5.012 -2.7l-.196 -.3c-.312 -.479 -1.407 -2.388 -3.286 -5.728a1.5 1.5 0 0 1 .536 -2.022a1.867 1.867 0 0 1 2.28 .28l1.47 1.47" />
              </svg>
            </button>
            <button className="inventory-control__button inventory-control__button--drop" ref={dropToFloor} title="Yere At (Sürükle & Bırak)">
              <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" strokeWidth="2" stroke="currentColor" fill="none" strokeLinecap="round" strokeLinejoin="round">
                <path stroke="none" d="M0 0h24v24H0z" fill="none" />
                <path d="M4 7l16 0" />
                <path d="M10 11l0 6" />
                <path d="M14 11l0 6" />
                <path d="M5 7l1 12a2 2 0 0 0 2 2h8a2 2 0 0 0 2 -2l1 -12" />
                <path d="M9 7v-3a1 1 0 0 1 1 -1h4a1 1 0 0 1 1 1v3" />
              </svg>
            </button>
            <button className="inventory-control__button" ref={give} title="Ver (Sürükle & Bırak)">
              <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" strokeWidth="2" stroke="currentColor" fill="none" strokeLinecap="round" strokeLinejoin="round">
                <path stroke="none" d="M0 0h24v24H0z" fill="none" />
                <path d="M21 17l-18 0" />
                <path d="M6 10l-3 -3l3 -3" />
                <path d="M3 7l18 0" />
                <path d="M18 20l3 -3l-3 -3" />
              </svg>
            </button>
            <button className="inventory-control__button inventory-control__button--close" onClick={() => fetchNui('exit')} title="Kapat">
              <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" strokeWidth="2" stroke="currentColor" fill="none" strokeLinecap="round" strokeLinejoin="round">
                <path stroke="none" d="M0 0h24v24H0z" fill="none" />
                <path d="M18 6l-12 12" />
                <path d="M6 6l12 12" />
              </svg>
            </button>
          </div>
        </div>
      </div>

      <button className="useful-controls-button" onClick={() => setInfoVisible(true)}>
        <svg xmlns="http://www.w3.org/2000/svg" height="2em" viewBox="0 0 524 524">
          <path d="M256 512A256 256 0 1 0 256 0a256 256 0 1 0 0 512zM216 336h24V272H216c-13.3 0-24-10.7-24-24s10.7-24 24-24h48c13.3 0 24 10.7 24 24v88h8c13.3 0 24 10.7 24 24s-10.7 24-24 24H216c-13.3 0-24-10.7-24-24s10.7-24 24-24zm40-208a32 32 0 1 1 0 64 32 32 0 1 1 0-64z" />
        </svg>
      </button>
    </>
  );
};

export default InventoryControl;
