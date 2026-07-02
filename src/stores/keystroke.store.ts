import { solNative } from "lib/SolNative";
import { makeAutoObservable } from "mobx";
import { Clipboard, type EmitterSubscription, Linking } from "react-native";
import type { IRootStore } from "store";
import { isValidCustomSearchEngineUrl } from "widgets/settings/general";
import { ItemType, Widget } from "./ui.store";
import { formatTemporaryResultForClipboard } from "./ui.store.helpers";

let keyDownListener: EmitterSubscription | undefined;
let keyUpListener: EmitterSubscription | undefined;


export type KeystrokeStore = ReturnType<typeof createKeystrokeStore>;

export const createKeystrokeStore = (root: IRootStore) => {
	const store = makeAutoObservable({
		commandPressed: false,
		shiftPressed: false,
		controlPressed: false,

		simulateEnter: () => {
			store.keyDown({ keyCode: 36, meta: false, shift: false });
		},
		keyDown: async ({
			keyCode,
			meta,
			shift,
		}: {
			keyCode: number;
			meta: boolean;
			shift: boolean;
		}) => {
			switch (keyCode) {
				// "j" key
				case 38: {
					// simulate a down key press
					if (store.controlPressed) {
						store.keyDown({ keyCode: 125, meta: false, shift: false });
					}
					break;
				}
				// "k" key
				case 40: {
					if (store.controlPressed) {
						store.keyDown({ keyCode: 126, meta: false, shift: false });
					}
					break;
				}
				// delete key
				case 51: {
					if (
						store.shiftPressed &&
						root.ui.focusedWidget === Widget.SEARCH &&
						root.ui.currentItem != null &&
						root.ui.currentItem.type === ItemType.CUSTOM
					) {
						root.ui.deleteCustomItem(root.ui.currentItem.id);
						return;
					}

					break;
				}
				// "e" key
				case 14: {
					if (
						meta &&
						root.ui.focusedWidget === Widget.SEARCH &&
						root.ui.currentItem != null &&
						root.ui.currentItem.type === ItemType.CUSTOM
					) {
						root.ui.setEditingCustomItem(root.ui.currentItem);
						root.ui.focusWidget(Widget.CREATE_ITEM);
					}
					break;
				}
				// tab key
				case 48: {

					break;
				}

				// enter key
				case 36: {
					if (root.ui.confirmDialogShown) {
						root.ui.executeConfirmCallback();
						return;
					}

					root.ui.setHistoryPointer(0);
					switch (root.ui.focusedWidget) {
						case Widget.FILE_SEARCH: {
							const file = root.ui.files[root.ui.selectedIndex];
							if (file?.url) {
								if (shift) {
									const filePath = file.url;
									const directoryPath = filePath.substring(
										0,
										filePath.lastIndexOf("/"),
									);
									solNative.openFinderAt(directoryPath);
								} else {
									solNative.openFile(file.url);
									solNative.hideWindow();
								}
							}
							break;
						}

						case Widget.PROCESSES: {
							const process =
								root.processes.filteredProcesses[root.ui.selectedIndex];
							if (process) {
								solNative.killProcess(process.id.toString());
							}
							solNative.hideWindow();
							solNative.showToast(
								`Process "${process.processName}" killed`,
								"success",
							);
							break;
						}

						case Widget.ONBOARDING: {
							switch (root.ui.onboardingStep) {
								case "v1_start": {
									root.ui.onboardingStep = "v1_shortcut";
									break;
								}

								case "v1_shortcut": {
									if (shift) {
										root.ui.openKeyboardSettings();
										return;
									}

									root.ui.onboardingStep = "v1_quick_actions";
									break;
								}

								case "v1_quick_actions": {
									root.ui.onboardingStep = "v1_completed";
									break;
								}
							}
							break;
						}


						case Widget.SEARCH: {

							if (!root.ui.query && !root.ui.isAccessibilityTrusted) {
								solNative.requestAccessibilityAccess();
								solNative.hideWindow();
								return;
							}

							if (!root.ui.query) {
								return;
							}

							//    ____  _    _ ______ _______     __  ______ _   _ _______ ______ _____  ______ _____
							//   / __ \| |  | |  ____|  __ \ \   / / |  ____| \ | |__   __|  ____|  __ \|  ____|  __ \
							//  | |  | | |  | | |__  | |__) \ \_/ /  | |__  |  \| |  | |  | |__  | |__) | |__  | |  | |
							//  | |  | | |  | |  __| |  _  / \   /   |  __| | . ` |  | |  |  __| |  _  /|  __| | |  | |
							//  | |__| | |__| | |____| | \ \  | |    | |____| |\  |  | |  | |____| | \ \| |____| |__| |
							//   \___\_\\____/|______|_|  \_\ |_|    |______|_| \_|  |_|  |______|_|  \_\______|_____/

							root.ui.addToHistory(root.ui.query);



							// If there are no visible items, or if the query is a meta (⌘ is pressed) query, open a browser search
							if (!root.ui.searchItems.length || meta) {
								switch (root.ui.searchEngine) {
									case "google":
										Linking.openURL(
											`https://google.com/search?q=${encodeURI(root.ui.query)}`,
										).catch((e) => {
											solNative.showToast(
												`Could not open URL: ${root.ui.query}, error: ${e}`,
												"error",
											);
										});
										break;
									case "duckduckgo":
										Linking.openURL(
											`https://duckduckgo.com/?q=${encodeURI(root.ui.query)}`,
										).catch((e) => {
											solNative.showToast(
												`Could not open URL: ${root.ui.query}, error: ${e}`,
												"error",
											);
										});
										break;
									case "bing":
										Linking.openURL(
											`https://bing.com/search?q=${encodeURI(root.ui.query)}`,
										).catch((e) => {
											solNative.showToast(
												`Could not open URL: ${root.ui.query}, error: ${e}`,
												"error",
											);
										});
										break;
									case "perplexity":
										Linking.openURL(
											`https://perplexity.ai/search/new?q=${encodeURI(
												root.ui.query,
											)}`,
										).catch((e) => {
											solNative.showToast(
												`Could not open URL: ${root.ui.query}, error: ${e}`,
												"error",
											);
										});
										break;
									case "custom":
										if (
											!isValidCustomSearchEngineUrl(root.ui.customSearchUrl)
										) {
											solNative.showToast(
												`Invalid search URL. Please ensure the URL is a valid search engine URL and includes a query parameter. Example: https://google.com/search?q=%s`,
												"error",
											);
											break;
										}
										Linking.openURL(
											root.ui.customSearchUrl.replace(
												"%s",
												encodeURI(root.ui.query),
											),
										).catch((e) => {
											solNative.showToast(
												`Could not open URL: ${root.ui.query}, error: ${e}`,
												"error",
											);
										});
										break;
								}

								solNative.hideWindow();
								return;
							}

							const item = root.ui.searchItems[root.ui.selectedIndex];

							if (item == null) {
								return;
							}

							if (
								item.type === ItemType.TEMPORARY_RESULT &&
								root.ui.temporaryResult
							) {
								Clipboard.setString(
									formatTemporaryResultForClipboard(root.ui.temporaryResult),
								);
								solNative.showToast("Copied to clipboard", "success");
								solNative.hideWindow();
								return;
							}

							root.ui.recordItemSelection(item);

							// close window
							if (!item.preventClose) {
								solNative.hideWindow();
							}

							if (store.commandPressed && item.metaCallback) {
								item.metaCallback();
								return;
							}

							if (item.callback) {
								item.callback();
								return;
							}

							if (item.url) {
								solNative.openFile(item.url);
								return;
							}

							if (item.type === ItemType.CUSTOM) {
								if (!item.text) {
									return;
								}

								if (item.isApplescript) {
									solNative.executeAppleScript(item.text);
								} else {
									try {
										const canOpenURL = await Linking.canOpenURL(item.text);
										if (canOpenURL) {
											await Linking.openURL(item.text);
										} else {
											solNative.showToast(
												`Could not open URL: ${item.text}`,
												"error",
											);
										}
									} catch (e) {
										solNative.showToast(
											`Could not open URL: ${item.text}`,
											"error",
										);
									}
								}
							}

							break;
						}
					}
					break;
				}

				// esc key
				case 53: {
					if (root.ui.confirmDialogShown) {
						root.ui.closeConfirm();
						return;
					}

					switch (root.ui.focusedWidget) {
						case Widget.SEARCH:
						case Widget.GOOGLE_MAP:
							solNative.hideWindow();
							break;

						default:
							root.ui.setQuery("");
							break;
					}

					root.ui.focusWidget(Widget.SEARCH);
					break;
				}

				// left/right arrows are unused in Sol Lite.
				case 123:
				case 124:
					break;

				// up key
				case 126: {
					switch (root.ui.focusedWidget) {

						case Widget.ONBOARDING:
							root.ui.selectedIndex = Math.max(0, root.ui.selectedIndex - 1);

							if (root.ui.selectedIndex === 0) {
								root.ui.setGlobalShortcut("option");
							} else if (root.ui.selectedIndex === 1) {
								root.ui.setGlobalShortcut("control");
							} else {
								root.ui.setGlobalShortcut("command");
							}
							break;

						default:
							if (
								root.ui.focusedWidget === Widget.SEARCH &&
								root.ui.selectedIndex === 0 &&
								root.ui.history.length > 0
							) {
								root.ui.setQuery(
									root.ui.history[
										root.ui.history.length - 1 - root.ui.historyPointer
									],
								);

								root.ui.setHistoryPointer(
									Math.min(root.ui.history.length, root.ui.historyPointer + 1),
								);
								return;
							}

							root.ui.selectedIndex = Math.max(0, root.ui.selectedIndex - 1);
							break;
					}
					break;
				}

				// down key
				case 125: {
					switch (root.ui.focusedWidget) {

						case Widget.ONBOARDING:
							root.ui.selectedIndex = Math.min(2, root.ui.selectedIndex + 1);

							if (root.ui.selectedIndex === 0) {
								root.ui.setGlobalShortcut("option");
							} else if (root.ui.selectedIndex === 1) {
								root.ui.setGlobalShortcut("control");
							} else {
								root.ui.setGlobalShortcut("command");
							}
							break;


						case Widget.PROCESSES: {
							root.ui.selectedIndex = Math.min(
								root.ui.selectedIndex + 1,
								root.processes.filteredProcesses.length - 1,
							);
							break;
						}

						case Widget.FILE_SEARCH: {
							root.ui.selectedIndex = Math.min(
								root.ui.selectedIndex + 1,
								root.ui.files.length - 1,
							);
							break;
						}
					}
					break;
				}

				// "1"
				// case 18: {
				//   if (meta) {
				//     if (root.ui.query) {
				//       Linking.openURL(`https://google.com/search?q=${root.ui.query}`)
				//       root.ui.query = ''
				//     }
				//   }
				//   break
				// }

				// // "2"
				// case 19: {
				//   if (meta) {
				//     if (root.ui.query) {
				//       root.ui.translateQuery()
				//     }
				//   }
				//   break
				// }

				// // "3"
				// case 20: {
				//   if (meta) {
				//     if (root.ui.query) {
				//       root.ui.focusedWidget = Widget.GOOGLE_MAP
				//     } else {
				//       root.ui.runFavorite(2)
				//     }
				//   }
				//   break
				// }

				// "4"
				// case 21: {
				//   if (meta) {
				//     root.ui.runFavorite(3)
				//   }
				//   break
				// }

				// // "5"
				// case 23: {
				//   if (meta) {
				//     root.ui.runFavorite(4)
				//   }
				//   break
				// }

				// meta key
				case 55: {
					store.commandPressed = true;
					break;
				}

				// shift key
				case 60: {
					store.shiftPressed = true;
					break;
				}

				// control key
				case 59: {
					store.controlPressed = true;
					break;
				}
			}
		},
		keyUp: async ({
			keyCode,
		}: {
			key: string;
			keyCode: number;
			meta: boolean;
		}) => {
			switch (keyCode) {
				case 55:
					store.commandPressed = false;
					break;

				case 60: {
					store.shiftPressed = false;
					break;
				}

				case 59: {
					store.controlPressed = false;
					break;
				}

				default:
					break;
			}
		},
		cleanUp: () => {
			keyDownListener?.remove();
			keyUpListener?.remove();
		},
	});

	keyDownListener = solNative.addListener("keyDown", store.keyDown);
	keyUpListener = solNative.addListener("keyUp", store.keyUp);

	return store;
};
