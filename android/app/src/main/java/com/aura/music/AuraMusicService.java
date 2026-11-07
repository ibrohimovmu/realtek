package com.aura.music;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.BroadcastReceiver;
import android.content.ContentResolver;
import android.content.ContentUris;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.ServiceInfo;
import android.database.Cursor;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.drawable.Icon;
import android.media.AudioAttributes;
import android.media.AudioManager;
import android.media.MediaMetadata;
import android.media.MediaPlayer;
import android.media.audiofx.BassBoost;
import android.media.audiofx.Equalizer;
import android.media.session.MediaSession;
import android.media.session.PlaybackState;
import android.net.Uri;
import android.os.Binder;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.os.PowerManager;
import android.provider.MediaStore;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.InputStream;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * AURA Native Foreground Music Service (API 26 - 35).
 * - Gapless MediaPlayer audio playback engine.
 * - Native Android MediaSession for Lock Screen & Bluetooth Controls.
 * - System Notification with MediaStyle and lockscreen controls.
 * - 5-Band Equalizer & BassBoost.
 * - Sleep Timer with volume fade-out.
 * - Headphone disconnect auto-pause.
 */
public class AuraMusicService extends Service implements MediaPlayer.OnPreparedListener,
        MediaPlayer.OnCompletionListener, MediaPlayer.OnErrorListener {

    public static final String ACTION_TOGGLE = "com.aura.music.ACTION_TOGGLE";
    public static final String ACTION_NEXT = "com.aura.music.ACTION_NEXT";
    public static final String ACTION_PREV = "com.aura.music.ACTION_PREV";
    public static final String ACTION_STOP = "com.aura.music.ACTION_STOP";

    private static final String CHANNEL_ID = "aura_playback_channel";
    private static final int NOTIF_ID = 2026;

    private static AuraMusicService instance;

    private MediaPlayer mediaPlayer;
    private MediaSession mediaSession;
    private Equalizer equalizer;
    private BassBoost bassBoost;

    private final IBinder binder = new LocalBinder();
    private final Handler handler = new Handler(Looper.getMainLooper());

    private final List<Track> playlist = new ArrayList<>();
    private final List<Integer> playQueue = new ArrayList<>();
    private int currentQueueIndex = -1;

    private boolean isShuffle = false;
    private int repeatMode = 1; // 0 = off, 1 = all, 2 = one

    private long sleepTimerEndMs = 0L;
    private float currentVolume = 1.0f;

    public static class Track {
        public long id;
        public String title;
        public String artist;
        public String album;
        public long duration;
        public String uriString;
        public String albumArtUri;
        public boolean isLocal;

        public JSONObject toJson() {
            JSONObject o = new JSONObject();
            try {
                o.put("id", id);
                o.put("title", title != null ? title : "Noma'lum trek");
                o.put("artist", artist != null ? artist : "AURA Artist");
                o.put("album", album != null ? album : "AURA");
                o.put("duration", duration);
                o.put("uri", uriString != null ? uriString : "");
                o.put("albumArt", albumArtUri != null ? albumArtUri : "");
                o.put("isLocal", isLocal);
            } catch (Throwable ignored) {}
            return o;
        }
    }

    public class LocalBinder extends Binder {
        public AuraMusicService getService() {
            return AuraMusicService.this;
        }
    }

    public static AuraMusicService getInstance() {
        return instance;
    }

    @Override
    public void onCreate() {
        super.onCreate();
        instance = this;

        initMediaPlayer();
        initMediaSession();
        createNotificationChannel();
        registerNoisyReceiver();

        loadDefaultSampleTracks();

        handler.post(progressTicker);
    }

    private void initMediaPlayer() {
        if (mediaPlayer != null) {
            try {
                mediaPlayer.release();
            } catch (Throwable ignored) {}
        }
        mediaPlayer = new MediaPlayer();
        mediaPlayer.setWakeMode(getApplicationContext(), PowerManager.PARTIAL_WAKE_LOCK);
        mediaPlayer.setAudioAttributes(new AudioAttributes.Builder()
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .build());

        mediaPlayer.setOnPreparedListener(this);
        mediaPlayer.setOnCompletionListener(this);
        mediaPlayer.setOnErrorListener(this);

        initAudioEffects();
    }

    private void initAudioEffects() {
        try {
            if (mediaPlayer != null) {
                int sessionId = mediaPlayer.getAudioSessionId();
                if (sessionId != 0) {
                    equalizer = new Equalizer(0, sessionId);
                    equalizer.setEnabled(true);

                    bassBoost = new BassBoost(0, sessionId);
                    bassBoost.setEnabled(true);
                }
            }
        } catch (Throwable ignored) {}
    }

    private void initMediaSession() {
        mediaSession = new MediaSession(this, "AuraMediaSession");
        mediaSession.setCallback(new MediaSession.Callback() {
            @Override
            public void onPlay() {
                resume();
            }

            @Override
            public void onPause() {
                pause();
            }

            @Override
            public void onSkipToNext() {
                next();
            }

            @Override
            public void onSkipToPrevious() {
                prev();
            }

            @Override
            public void onSeekTo(long pos) {
                seekTo((int) pos);
            }

            @Override
            public void onStop() {
                pause();
                stopForeground(false);
            }
        });
        mediaSession.setActive(true);
    }

    private final BroadcastReceiver noisyReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            if (AudioManager.ACTION_AUDIO_BECOMING_NOISY.equals(intent.getAction())) {
                pause();
            }
        }
    };

    private void registerNoisyReceiver() {
        IntentFilter filter = new IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY);
        registerReceiver(noisyReceiver, filter);
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent != null && intent.getAction() != null) {
            switch (intent.getAction()) {
                case ACTION_TOGGLE:
                    if (isPlaying()) pause();
                    else resume();
                    break;
                case ACTION_NEXT:
                    next();
                    break;
                case ACTION_PREV:
                    prev();
                    break;
                case ACTION_STOP:
                    pause();
                    stopForeground(true);
                    break;
            }
        }
        return START_NOT_STICKY;
    }

    @Override
    public IBinder onBind(Intent intent) {
        return binder;
    }

    // ========================================================================
    // PLAYBACK CONTROLS
    // ========================================================================
    public void playIndex(int index) {
        if (index < 0 || index >= playlist.size()) return;
        currentQueueIndex = index;
        Track track = playlist.get(index);
        playTrackInternal(track);
    }

    private void playTrackInternal(Track track) {
        try {
            if (mediaPlayer == null) initMediaPlayer();
            mediaPlayer.reset();

            Uri trackUri = Uri.parse(track.uriString);
            mediaPlayer.setDataSource(this, trackUri);
            mediaPlayer.prepareAsync();

            updateMediaSessionMetadata(track);
            updatePlaybackState(PlaybackState.STATE_BUFFERING, 0);
            startForegroundNotification(track, true);

            MainActivity.notifyJs("onTrackChanged", track.toJson().toString());
        } catch (Throwable t) {
            next();
        }
    }

    public void pause() {
        if (mediaPlayer != null && mediaPlayer.isPlaying()) {
            mediaPlayer.pause();
            Track cur = getCurrentTrack();
            if (cur != null) {
                updatePlaybackState(PlaybackState.STATE_PAUSED, mediaPlayer.getCurrentPosition());
                startForegroundNotification(cur, false);
            }
            MainActivity.notifyJs("onPlaybackState", "{\"state\":\"paused\",\"position\":"
                    + getPosition() + ",\"duration\":" + getDuration() + "}");
        }
    }

    public void resume() {
        if (mediaPlayer != null && !mediaPlayer.isPlaying()) {
            mediaPlayer.start();
            Track cur = getCurrentTrack();
            if (cur != null) {
                updatePlaybackState(PlaybackState.STATE_PLAYING, mediaPlayer.getCurrentPosition());
                startForegroundNotification(cur, true);
            }
            MainActivity.notifyJs("onPlaybackState", "{\"state\":\"playing\",\"position\":"
                    + getPosition() + ",\"duration\":" + getDuration() + "}");
        }
    }

    public void togglePlayPause() {
        if (isPlaying()) pause();
        else resume();
    }

    public void seekTo(int msec) {
        if (mediaPlayer != null) {
            mediaPlayer.seekTo(msec);
            updatePlaybackState(isPlaying() ? PlaybackState.STATE_PLAYING : PlaybackState.STATE_PAUSED, msec);
        }
    }

    public void next() {
        if (playlist.isEmpty()) return;
        if (currentQueueIndex + 1 < playlist.size()) {
            currentQueueIndex++;
        } else {
            if (repeatMode == 1) { // repeat all
                currentQueueIndex = 0;
            } else {
                return;
            }
        }
        playIndex(currentQueueIndex);
    }

    public void prev() {
        if (playlist.isEmpty()) return;
        if (getPosition() > 3000) {
            seekTo(0);
            return;
        }
        if (currentQueueIndex - 1 >= 0) {
            currentQueueIndex--;
        } else {
            currentQueueIndex = playlist.size() - 1;
        }
        playIndex(currentQueueIndex);
    }

    public boolean isPlaying() {
        try {
            return mediaPlayer != null && mediaPlayer.isPlaying();
        } catch (Throwable t) {
            return false;
        }
    }

    public int getPosition() {
        try {
            return mediaPlayer != null ? mediaPlayer.getCurrentPosition() : 0;
        } catch (Throwable t) {
            return 0;
        }
    }

    public int getDuration() {
        try {
            return mediaPlayer != null ? mediaPlayer.getDuration() : 0;
        } catch (Throwable t) {
            return 0;
        }
    }

    public Track getCurrentTrack() {
        if (currentQueueIndex >= 0 && currentQueueIndex < playlist.size()) {
            return playlist.get(currentQueueIndex);
        }
        return null;
    }

    public int getCurrentIndex() {
        return currentQueueIndex;
    }

    public void setShuffle(boolean shuffle) {
        this.isShuffle = shuffle;
        if (shuffle) {
            Collections.shuffle(playQueue);
        }
    }

    public boolean isShuffle() {
        return isShuffle;
    }

    public void setRepeatMode(int mode) {
        this.repeatMode = mode;
    }

    public int getRepeatMode() {
        return repeatMode;
    }

    // ========================================================================
    // SLEEP TIMER WITH SMOOTH FADE-OUT
    // ========================================================================
    public void setSleepTimer(int minutes) {
        if (minutes <= 0) {
            sleepTimerEndMs = 0L;
            setPlayerVolume(1.0f);
            MainActivity.notifyJs("onSleepTimerTick", "{\"remainingSeconds\":0}");
            return;
        }
        sleepTimerEndMs = System.currentTimeMillis() + (minutes * 60_000L);
        setPlayerVolume(1.0f);
    }

    private void checkSleepTimerTick() {
        if (sleepTimerEndMs <= 0L) return;
        long now = System.currentTimeMillis();
        long diff = sleepTimerEndMs - now;
        if (diff <= 0) {
            sleepTimerEndMs = 0L;
            pause();
            setPlayerVolume(1.0f);
            MainActivity.notifyJs("onSleepTimerTick", "{\"remainingSeconds\":0,\"finished\":true}");
            return;
        }

        if (diff < 30_000L) {
            float fade = (float) diff / 30_000f;
            setPlayerVolume(Math.max(0.05f, fade));
        }

        int secLeft = (int) (diff / 1000L);
        MainActivity.notifyJs("onSleepTimerTick", "{\"remainingSeconds\":" + secLeft + "}");
    }

    private void setPlayerVolume(float vol) {
        currentVolume = vol;
        if (mediaPlayer != null) {
            try {
                mediaPlayer.setVolume(vol, vol);
            } catch (Throwable ignored) {}
        }
    }

    // ========================================================================
    // EQUALIZER & BASSBOOST
    // ========================================================================
    public void setEqualizerBandLevel(short band, short level) {
        if (equalizer != null) {
            try {
                equalizer.setBandLevel(band, level);
            } catch (Throwable ignored) {}
        }
    }

    public void setBassBoostStrength(short strength) {
        if (bassBoost != null) {
            try {
                bassBoost.setStrength(strength);
            } catch (Throwable ignored) {}
        }
    }

    public String getEqualizerJson() {
        JSONObject obj = new JSONObject();
        try {
            if (equalizer != null) {
                obj.put("bandsCount", equalizer.getNumberOfBands());
                JSONArray levels = new JSONArray();
                for (short i = 0; i < equalizer.getNumberOfBands(); i++) {
                    levels.put(equalizer.getBandLevel(i));
                }
                obj.put("levels", levels);
            }
            if (bassBoost != null) {
                obj.put("bassStrength", bassBoost.getRoundedStrength());
            }
        } catch (Throwable ignored) {}
        return obj.toString();
    }

    // ========================================================================
    // MEDIA PLAYER LISTENERS
    // ========================================================================
    @Override
    public void onPrepared(MediaPlayer mp) {
        mp.start();
        Track cur = getCurrentTrack();
        if (cur != null) {
            updatePlaybackState(PlaybackState.STATE_PLAYING, 0);
            startForegroundNotification(cur, true);
        }
        MainActivity.notifyJs("onPlaybackState", "{\"state\":\"playing\",\"position\":0,\"duration\":"
                + getDuration() + "}");
    }

    @Override
    public void onCompletion(MediaPlayer mp) {
        if (repeatMode == 2) {
            seekTo(0);
            resume();
        } else {
            next();
        }
    }

    @Override
    public boolean onError(MediaPlayer mp, int what, int extra) {
        next();
        return true;
    }

    // ========================================================================
    // LOCAL STORAGE SCANNER (MediaStore.Audio.Media)
    // ========================================================================
    public void scanLocalAudioFiles() {
        new Thread(() -> {
            List<Track> found = new ArrayList<>();
            ContentResolver resolver = getContentResolver();
            Uri musicUri = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI;
            String selection = MediaStore.Audio.Media.IS_MUSIC + "!= 0";
            String sortOrder = MediaStore.Audio.Media.TITLE + " ASC";

            String[] projection = {
                    MediaStore.Audio.Media._ID,
                    MediaStore.Audio.Media.TITLE,
                    MediaStore.Audio.Media.ARTIST,
                    MediaStore.Audio.Media.ALBUM,
                    MediaStore.Audio.Media.DURATION,
                    MediaStore.Audio.Media.DATA,
                    MediaStore.Audio.Media.ALBUM_ID
            };

            try (Cursor cursor = resolver.query(musicUri, projection, selection, null, sortOrder)) {
                if (cursor != null && cursor.moveToFirst()) {
                    int idCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID);
                    int titleCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE);
                    int artistCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST);
                    int albumCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM);
                    int durCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION);
                    int albumIdCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM_ID);

                    do {
                        long id = cursor.getLong(idCol);
                        long duration = cursor.getLong(durCol);
                        if (duration < 15_000) continue;

                        String title = cursor.getString(titleCol);
                        String artist = cursor.getString(artistCol);
                        String album = cursor.getString(albumCol);
                        long albumId = cursor.getLong(albumIdCol);

                        Uri contentUri = ContentUris.withAppendedId(musicUri, id);
                        Uri artUri = ContentUris.withAppendedId(
                                Uri.parse("content://media/external/audio/albumart"), albumId);

                        Track t = new Track();
                        t.id = id;
                        t.title = (title != null && !title.isEmpty()) ? title : "Audio Track";
                        t.artist = (artist != null && !artist.equals("<unknown>")) ? artist : "Unknown Artist";
                        t.album = (album != null) ? album : "Local Music";
                        t.duration = duration;
                        t.uriString = contentUri.toString();
                        t.albumArtUri = artUri.toString();
                        t.isLocal = true;

                        found.add(t);
                    } while (cursor.moveToNext());
                }
            } catch (Throwable ignored) {}

            handler.post(() -> {
                if (!found.isEmpty()) {
                    playlist.clear();
                    playlist.addAll(found);
                } else {
                    loadDefaultSampleTracks();
                }
                notifyTracksLoaded();
            });
        }).start();
    }

    private void loadDefaultSampleTracks() {
        playlist.clear();

        Track t1 = new Track();
        t1.id = 101;
        t1.title = "Cyber Pulse (Synthwave)";
        t1.artist = "AURA Originals";
        t1.album = "Neon Drift";
        t1.duration = 186000;
        t1.uriString = "https://cdn.pixabay.com/download/audio/2022/03/10/audio_c8c8a73467.mp3?filename=synthwave-80s-110045.mp3";
        t1.albumArtUri = "https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=500&q=80";
        t1.isLocal = false;
        playlist.add(t1);

        Track t2 = new Track();
        t2.id = 102;
        t2.title = "Midnight Horizon";
        t2.artist = "Celestial Mirage";
        t2.album = "Cosmic Vinyl";
        t2.duration = 214000;
        t2.uriString = "https://cdn.pixabay.com/download/audio/2022/01/18/audio_d0a13f69d2.mp3?filename=electronic-future-beats-117997.mp3";
        t2.albumArtUri = "https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500&q=80";
        t2.isLocal = false;
        playlist.add(t2);

        Track t3 = new Track();
        t3.id = 103;
        t3.title = "Lo-Fi Raindrops & Vinyl";
        t3.artist = "Tokyo Nightclub";
        t3.album = "Shinjuku Lofi";
        t3.duration = 165000;
        t3.uriString = "https://cdn.pixabay.com/download/audio/2022/05/27/audio_1808fbf07a.mp3?filename=lofi-study-112191.mp3";
        t3.albumArtUri = "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80";
        t3.isLocal = false;
        playlist.add(t3);

        Track t4 = new Track();
        t4.id = 104;
        t4.title = "Solar Flare (Deep Bass)";
        t4.artist = "Hyperdrive";
        t4.album = "Quantum Speed";
        t4.duration = 198000;
        t4.uriString = "https://cdn.pixabay.com/download/audio/2022/01/26/audio_d0c6ff1cbd.mp3?filename=the-cradle-of-your-soul-15700.mp3";
        t4.albumArtUri = "https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&q=80";
        t4.isLocal = false;
        playlist.add(t4);
    }

    public void notifyTracksLoaded() {
        JSONArray arr = new JSONArray();
        for (Track t : playlist) {
            arr.put(t.toJson());
        }
        MainActivity.notifyJs("onTracksLoaded", arr.toString());
    }

    public String getPlaylistJson() {
        JSONArray arr = new JSONArray();
        for (Track t : playlist) {
            arr.put(t.toJson());
        }
        return arr.toString();
    }

    // ========================================================================
    // NATIVE SYSTEM NOTIFICATION & MEDIASESSION (Android 11 - 15 Lock Screen)
    // ========================================================================
    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel chan = new NotificationChannel(
                    CHANNEL_ID,
                    "AURA Music Playback",
                    NotificationManager.IMPORTANCE_LOW
            );
            chan.setDescription("Music playback controls on lock screen and status bar");
            chan.setShowBadge(false);
            chan.setLockscreenVisibility(Notification.VISIBILITY_PUBLIC);
            NotificationManager nm = getSystemService(NotificationManager.class);
            if (nm != null) nm.createNotificationChannel(chan);
        }
    }

    private void updateMediaSessionMetadata(Track track) {
        if (mediaSession == null || track == null) return;
        MediaMetadata.Builder b = new MediaMetadata.Builder()
                .putString(MediaMetadata.METADATA_KEY_TITLE, track.title)
                .putString(MediaMetadata.METADATA_KEY_ARTIST, track.artist)
                .putString(MediaMetadata.METADATA_KEY_ALBUM, track.album)
                .putLong(MediaMetadata.METADATA_KEY_DURATION, track.duration);

        try {
            Bitmap art = loadAlbumArtBitmap(track);
            if (art != null) {
                b.putBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART, art);
                b.putBitmap(MediaMetadata.METADATA_KEY_ART, art);
            }
        } catch (Throwable ignored) {}

        mediaSession.setMetadata(b.build());
    }

    private void updatePlaybackState(int state, long position) {
        if (mediaSession == null) return;
        long actions = PlaybackState.ACTION_PLAY
                | PlaybackState.ACTION_PAUSE
                | PlaybackState.ACTION_SKIP_TO_NEXT
                | PlaybackState.ACTION_SKIP_TO_PREVIOUS
                | PlaybackState.ACTION_SEEK_TO
                | PlaybackState.ACTION_STOP;

        mediaSession.setPlaybackState(new PlaybackState.Builder()
                .setActions(actions)
                .setState(state, position, 1.0f)
                .build());
    }

    private void startForegroundNotification(Track track, boolean isPlaying) {
        if (track == null) return;

        PendingIntent openAppPi = PendingIntent.getActivity(
                this, 0,
                new Intent(this, MainActivity.class),
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );

        PendingIntent prevPi = PendingIntent.getService(
                this, 1,
                new Intent(this, AuraMusicService.class).setAction(ACTION_PREV),
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );

        PendingIntent togglePi = PendingIntent.getService(
                this, 2,
                new Intent(this, AuraMusicService.class).setAction(ACTION_TOGGLE),
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );

        PendingIntent nextPi = PendingIntent.getService(
                this, 3,
                new Intent(this, AuraMusicService.class).setAction(ACTION_NEXT),
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );

        Notification.MediaStyle mediaStyle = new Notification.MediaStyle()
                .setMediaSession(mediaSession.getSessionToken())
                .setShowActionsInCompactView(0, 1, 2);

        int playPauseIcon = isPlaying ? android.R.drawable.ic_media_pause : android.R.drawable.ic_media_play;

        Notification.Builder notifBuilder;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            notifBuilder = new Notification.Builder(this, CHANNEL_ID);
        } else {
            notifBuilder = new Notification.Builder(this);
        }

        notifBuilder.setSmallIcon(android.R.drawable.ic_media_play)
                .setContentTitle(track.title)
                .setContentText(track.artist + " • " + track.album)
                .setContentIntent(openAppPi)
                .setVisibility(Notification.VISIBILITY_PUBLIC)
                .setStyle(mediaStyle)
                .addAction(new Notification.Action.Builder(
                        Icon.createWithResource(this, android.R.drawable.ic_media_previous),
                        "Previous", prevPi).build())
                .addAction(new Notification.Action.Builder(
                        Icon.createWithResource(this, playPauseIcon),
                        isPlaying ? "Pause" : "Play", togglePi).build())
                .addAction(new Notification.Action.Builder(
                        Icon.createWithResource(this, android.R.drawable.ic_media_next),
                        "Next", nextPi).build())
                .setOngoing(isPlaying);

        Bitmap art = loadAlbumArtBitmap(track);
        if (art != null) {
            notifBuilder.setLargeIcon(art);
        }

        Notification notification = notifBuilder.build();

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(NOTIF_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK);
            } else {
                startForeground(NOTIF_ID, notification);
            }
        } catch (Throwable ignored) {
            try {
                startForeground(NOTIF_ID, notification);
            } catch (Throwable ignored2) {}
        }
    }

    private Bitmap loadAlbumArtBitmap(Track track) {
        if (track == null || track.albumArtUri == null) return null;
        try {
            if (track.isLocal) {
                Uri artUri = Uri.parse(track.albumArtUri);
                InputStream is = getContentResolver().openInputStream(artUri);
                if (is != null) {
                    Bitmap bmp = BitmapFactory.decodeStream(is);
                    is.close();
                    return bmp;
                }
            }
        } catch (Throwable ignored) {}
        return null;
    }

    // ========================================================================
    // PERIODIC PROGRESS TICKER
    // ========================================================================
    private final Runnable progressTicker = new Runnable() {
        @Override
        public void run() {
            if (isPlaying()) {
                MainActivity.notifyJs("onPlaybackProgress", "{\"position\":" + getPosition()
                        + ",\"duration\":" + getDuration() + "}");
            }
            checkSleepTimerTick();
            handler.postDelayed(this, 800L);
        }
    };

    @Override
    public void onDestroy() {
        instance = null;
        handler.removeCallbacksAndMessages(null);
        try {
            unregisterReceiver(noisyReceiver);
        } catch (Throwable ignored) {}
        if (mediaPlayer != null) {
            try {
                mediaPlayer.release();
            } catch (Throwable ignored) {}
            mediaPlayer = null;
        }
        if (mediaSession != null) {
            try {
                mediaSession.release();
            } catch (Throwable ignored) {}
            mediaSession = null;
        }
        super.onDestroy();
    }
}
