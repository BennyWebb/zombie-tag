package com.webb.zombietag;

import android.os.Bundle;
import android.view.InputDevice;
import android.view.KeyEvent;
import android.view.WindowManager;
import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        // Joypad play doesn't always count as using the TV, so stop the screensaver coming on mid-game
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
    }

    @Override
    public boolean dispatchKeyEvent(KeyEvent event) {
        // Android turns a joypad's B button into Back if nothing else uses it, but B is a fire
        // button in the game, so it mustn't pause the game or go back. The real Back button
        // (on the remote or the controller) isn't a fallback, so it still works.
        boolean fromPad = (event.getSource() & InputDevice.SOURCE_GAMEPAD) == InputDevice.SOURCE_GAMEPAD;
        if (event.getKeyCode() == KeyEvent.KEYCODE_BACK && fromPad && (event.getFlags() & KeyEvent.FLAG_FALLBACK) != 0) {
            return true;
        }
        return super.dispatchKeyEvent(event);
    }
}
