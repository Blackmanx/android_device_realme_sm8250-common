/*
 * Copyright (C) 2020 The LineageOS Project
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 *
 */
package com.realmeparts;

import android.app.NotificationManager;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.SystemProperties;
import android.widget.Toast;

import androidx.preference.Preference;
import androidx.preference.Preference.OnPreferenceChangeListener;
import androidx.preference.PreferenceManager;

import static com.realmeparts.DeviceSettings.TP_GAME_MODE;

public class GameModeSwitch implements OnPreferenceChangeListener {
    public static final int GameMode_Notification_Channel_ID = 0x11011;
    private static final boolean GameMode = false;
    private static final String FILE = DeviceSettings.TP_GAME_MODE;
    private static Context mContext;
    private static NotificationManager mNotificationManager;
    private static int userSelectedDndMode;

    public GameModeSwitch(Context context) {
        mContext = context;
        userSelectedDndMode = mContext.getSystemService(NotificationManager.class).getCurrentInterruptionFilter();
    }


    public static String getFile() {
        return FILE;
    }

    public static boolean isSupported() {
        return true;
    }

    public static boolean isCurrentlyEnabled(Context context) {
        return Utils.getGameNode(FILE);
    }

    public static boolean checkNotificationPolicy(Context context) {
        mNotificationManager = (NotificationManager) mContext.getSystemService(Context.NOTIFICATION_SERVICE);
        return mNotificationManager.isNotificationPolicyAccessGranted();
    }

    public static void GameModeDND() {
        SharedPreferences sharedPreferences = PreferenceManager.getDefaultSharedPreferences(mContext);

        if (!checkNotificationPolicy(mContext)) {
            //Launch Do Not Disturb Access settings
            Intent DNDAccess = new Intent(android.provider.Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS);
            mContext.startActivity(DNDAccess);
        } else if (isCurrentlyEnabled(mContext)) {
            userSelectedDndMode = mContext.getSystemService(NotificationManager.class).getCurrentInterruptionFilter();
            if (sharedPreferences.getBoolean("dnd", false)) activateDND();
            AppNotification.Send(mContext, GameMode_Notification_Channel_ID, mContext.getString(R.string.game_mode_title), mContext.getString(R.string.game_mode_notif_content));
            ShowToast(sharedPreferences);
        } else if (!isCurrentlyEnabled(mContext)) {
            if (sharedPreferences.getBoolean("dnd", false))
                mNotificationManager.setInterruptionFilter(userSelectedDndMode);
            AppNotification.Cancel(mContext, GameMode_Notification_Channel_ID);
            ShowToast(sharedPreferences);
        }
    }

    public static void activateDND() {
        mNotificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY);
        mNotificationManager.setNotificationPolicy(
                new NotificationManager.Policy(NotificationManager.Policy.PRIORITY_CATEGORY_MEDIA, 0, 0));
    }

    public static void ShowToast(SharedPreferences s) {
        if (s.getBoolean("game", false))
            Toast.makeText(mContext, R.string.game_mode_deactivated_toast, Toast.LENGTH_SHORT).show();
        else
            Toast.makeText(mContext, R.string.game_mode_activated_toast, Toast.LENGTH_SHORT).show();
    }

    public boolean onPreferenceChange(Preference preference, Object newValue) {
        Boolean enabled = (Boolean) newValue;
        Utils.writeValue(getFile(), enabled ? "1" : "0");
        GameModeDND();
        return true;
    }
}
