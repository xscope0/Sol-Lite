import { createContext, useContext } from "react";
import {
	createKeystrokeStore,
	type KeystrokeStore,
} from "stores/keystroke.store";
import { createUIStore, type UIStore } from "./stores/ui.store";
import {
	type ProcessesStore,
	createProcessesStore,
} from "stores/processes.store";
import { type ScriptsStore, createScriptsStore } from "stores/scripts.store";

export interface IRootStore {
	ui: UIStore;
	keystroke: KeystrokeStore;
	processes: ProcessesStore;
	scripts: ScriptsStore;
	cleanUp: () => void;
}

const createRootStore = (): IRootStore => {
	const store: any = {};

	store.ui = createUIStore(store);
	store.keystroke = createKeystrokeStore(store);
	store.processes = createProcessesStore(store);
	store.scripts = createScriptsStore(store);
	(store as IRootStore).cleanUp = () => {
		store.ui.cleanUp();
		store.keystroke.cleanUp();
	};

	return store;
};

export const root = createRootStore();

// @ts-expect-error hot is RN
module.hot?.dispose(() => {
	root.cleanUp();
});

export const StoreContext = createContext<IRootStore>(root);
export const StoreProvider = StoreContext.Provider;
export const useStore = () => useContext(StoreContext);
