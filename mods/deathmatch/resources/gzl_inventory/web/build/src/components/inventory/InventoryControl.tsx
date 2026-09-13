import React from 'react';
import { useDrop } from 'react-dnd';
import { useAppDispatch, useAppSelector } from '../../store';
import { selectItemAmount, setItemAmount } from '../../store/inventory';
import { DragSource } from '../../typings';
import { onUse } from '../../dnd/onUse';
import { onGive } from '../../dnd/onGive';
import { fetchNui } from '../../utils/fetchNui';

const InventoryControl: React.FC = () => {
  const itemAmount = useAppSelector(selectItemAmount);
  const dispatch = useAppDispatch();


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

  return (
    <div className="inventory-control flex items-center justify-center px-3">
      <div className="grid grid-cols-1 gap-2.5">
        <input
          className="w-28 2k:w-32 4k:w-40 px-1 py-2.5 2k:py-4 4k:py-6 2k:text-xl 4k:text-3xl bg-dark border-zinc-700 bg-opacity-80 rounded-md text-center mb-8 focus:outline-none hover:border-gray-500 border border-transparent focus:border-indigo-400 transition-colors duration-300"
          type="number"
          defaultValue={itemAmount}
          onChange={(o) => {
            (o.target.valueAsNumber =
              isNaN(o.target.valueAsNumber) || o.target.valueAsNumber < 0
                ? 0
                : Math.floor(o.target.valueAsNumber)),
              dispatch(setItemAmount(o.target.valueAsNumber));
          }}
        />
        <div className="flex items-center justify-between flex-col space-y-3">
          <button
            className="inventory-control__button inventory-control__button--use"
            ref={use}
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="24"
              height="24"
              viewBox="0 0 24 24"
              strokeWidth="2"
              stroke="currentColor"
              fill="none"
              strokeLinecap="round"
              strokeLinejoin="round"
            >
              <path stroke="none" d="M0 0h24v24H0z" fill="none" />
              <path d="M8 11v-3.5a1.5 1.5 0 0 1 3 0v2.5" />
              <path d="M11 9.5v-3a1.5 1.5 0 0 1 3 0v3.5" />
              <path d="M14 7.5a1.5 1.5 0 0 1 3 0v2.5" />
              <path d="M17 9.5a1.5 1.5 0 0 1 3 0v4.5a6 6 0 0 1 -6 6h-2h.208a6 6 0 0 1 -5.012 -2.7l-.196 -.3c-.312 -.479 -1.407 -2.388 -3.286 -5.728a1.5 1.5 0 0 1 .536 -2.022a1.867 1.867 0 0 1 2.28 .28l1.47 1.47" />
            </svg>
          </button>
          <button className="inventory-control__button" ref={give}>
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="24"
              height="24"
              viewBox="0 0 24 24"
              strokeWidth="2"
              stroke="currentColor"
              fill="none"
              strokeLinecap="round"
              strokeLinejoin="round"
            >
              <path stroke="none" d="M0 0h24v24H0z" fill="none" />
              <path d="M21 17l-18 0" />
              <path d="M6 10l-3 -3l3 -3" />
              <path d="M3 7l18 0" />
              <path d="M18 20l3 -3l-3 -3" />
            </svg>
          </button>
          <button
            className="inventory-control__button inventory-control__button--close"
            onClick={() => fetchNui('exit')}
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="24"
              height="24"
              viewBox="0 0 24 24"
              strokeWidth="2"
              stroke="currentColor"
              fill="none"
              strokeLinecap="round"
              strokeLinejoin="round"
            >
              <path stroke="none" d="M0 0h24v24H0z" fill="none" />
              <path d="M18 6l-12 12" />
              <path d="M6 6l12 12" />
            </svg>
          </button>
        </div>
      </div>
    </div>
  );
};
export default InventoryControl;
