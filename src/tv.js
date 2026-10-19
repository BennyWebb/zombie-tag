// When the game runs as an Android TV app (the Nvidia Shield), Capacitor wraps it and gives it
// the remote's Back button. In a normal browser none of this does anything.

import { Capacitor } from '@capacitor/core';
import { App } from '@capacitor/app';

const isApp = Capacitor.isNativePlatform();

// Calls `fn` when the TV remote's (or a controller's) Back button is pressed.
export function onBackButton(fn) {
  if (isApp) App.addListener('backButton', fn);
}

// Closes the app and goes back to the TV's home screen.
export function exitApp() {
  if (isApp) App.exitApp();
}
