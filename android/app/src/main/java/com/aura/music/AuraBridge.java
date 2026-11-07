package com.aura.music;

import android.webkit.JavascriptInterface;

public class AuraBridge {

    private final MainActivity activity;

    public AuraBridge(MainActivity activity) {
        this.activity = activity;
    }

    @JavascriptInterface
    public void playTrack(int index) {
        AuraMusicService s = AuraMusicService.getInstance();
        if (s != null) {
            s.playIndex(index);
        }
    }

    @JavascriptInterface
    public void pause() {
        AuraMusicService s = AuraMusicService.getInstance();
        if (s != null) s.pause();
    }

    @JavascriptInterface
    public void resume() {
        AuraMusicService s = AuraMusicService.getInstance();
        if (s != null) s.resume();
    }

    @JavascriptInterface
    public void togglePlayPause() {
        AuraMusicService s = AuraMusicService.getInstance();
        if (s != null) s.togglePlayPause();
    }

    @JavascriptInterface
    public void next() {
        AuraMusicService s = AuraMusicService.getInstance();
        if (s != null) s.next();
    }

    @JavascriptInterface
    public void prev() {
        AuraMusicService s = AuraMusicService.getInstance();
        if (s != null) s.prev();
    }

    @JavascriptInterface
    public void seekTo(int ms) {
        AuraMusicService s = AuraMusicService.getInstance();
        if (s != null) s.seekTo(ms);
    }

    @JavascriptInterface
    public void setShuffle(boolean shuffle) {
        AuraMusicService s = AuraMusicService.getInstance();
        if (s != null) s.setShuffle(shuffle);
    }

    @JavascriptInterface
    public void setRepeatMode(int mode) {
        AuraMusicService s = AuraMusicService.getInstance();
        if (s != null) s.setRepeatMode(mode);
    }

    @JavascriptInterface
    public String getPlaylistJson() {
        AuraMusicService s = AuraMusicService.getInstance();
        if (s != null) {
            return s.getPlaylistJson();
        }
        return "[]";
    }

    @JavascriptInterface
    public void scanLocalAudio() {
        activity.checkStorageAndScan();
    }

    @JavascriptInterface
    public void setSleepTimer(int minutes) {
        AuraMusicService s = AuraMusicService.getInstance();
        if (s != null) s.setSleepTimer(minutes);
    }

    @JavascriptInterface
    public void setEqualizerBand(int band, int level) {
        AuraMusicService s = AuraMusicService.getInstance();
        if (s != null) s.setEqualizerBandLevel((short) band, (short) level);
    }

    @JavascriptInterface
    public void setBassBoost(int strength) {
        AuraMusicService s = AuraMusicService.getInstance();
        if (s != null) s.setBassBoostStrength((short) strength);
    }

    @JavascriptInterface
    public String getEqualizerJson() {
        AuraMusicService s = AuraMusicService.getInstance();
        if (s != null) return s.getEqualizerJson();
        return "{}";
    }

    @JavascriptInterface
    public void setLockscreenAmbient(boolean enabled) {
        activity.setLockscreenAmbient(enabled);
    }

    @JavascriptInterface
    public boolean isStorageGranted() {
        return activity.hasStoragePermission();
    }

    @JavascriptInterface
    public void requestStoragePermission() {
        activity.requestStoragePermission();
    }
}
