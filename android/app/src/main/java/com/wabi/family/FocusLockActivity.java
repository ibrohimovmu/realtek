package com.wabi.family;

import android.app.Activity;
import android.content.Intent;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.view.Gravity;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;

/**
 * FocusLockActivity (Warm Espresso Focus Lock HUD).
 * Shown instantly when an app limit is exceeded.
 */
public class FocusLockActivity extends Activity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        requestWindowFeature(Window.FEATURE_NO_TITLE);
        getWindow().setFlags(
                WindowManager.LayoutParams.FLAG_FULLSCREEN,
                WindowManager.LayoutParams.FLAG_FULLSCREEN
        );

        String blockedPkg = getIntent().getStringExtra("blocked_pkg");
        if (blockedPkg == null) blockedPkg = "Ushbu ilova";

        // Warm Espresso Luxury Container
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(Color.parseColor("#12100E")); // Deep Warm Espresso
        root.setGravity(Gravity.CENTER);
        root.setPadding(60, 60, 60, 60);

        // Glass Card
        LinearLayout card = new LinearLayout(this);
        card.setOrientation(LinearLayout.VERTICAL);
        card.setGravity(Gravity.CENTER);
        card.setPadding(64, 80, 64, 80);

        GradientDrawable cardBg = new GradientDrawable();
        cardBg.setColor(Color.parseColor("#1E1B18"));
        cardBg.setCornerRadius(60f);
        cardBg.setStroke(2, Color.parseColor("#38322B"));
        card.setBackground(cardBg);

        // Lock Icon Emoji
        TextView iconTv = new TextView(this);
        iconTv.setText("⏳");
        iconTv.setTextSize(54);
        iconTv.setGravity(Gravity.CENTER);
        card.addView(iconTv);

        // Title
        TextView titleTv = new TextView(this);
        titleTv.setText("Vaqt Chegarasi Tugadi");
        titleTv.setTextSize(24);
        titleTv.setTextColor(Color.parseColor("#F5EBE1"));
        titleTv.setTypeface(Typeface.DEFAULT_BOLD);
        titleTv.setGravity(Gravity.CENTER);
        titleTv.setPadding(0, 32, 0, 16);
        card.addView(titleTv);

        // Subtitle / Description
        TextView descTv = new TextView(this);
        descTv.setText("Ushbu ilova uchun ota-onangiz belgilagan kunlik vaqt limiti tugadi.\n\nQo'shimcha vaqt olish uchun WABI ichidagi vazifalarni bajaring yoki ota-onangiz bilan suhbatlashing.");
        descTv.setTextSize(15);
        descTv.setTextColor(Color.parseColor("#A89F91"));
        descTv.setGravity(Gravity.CENTER);
        descTv.setLineSpacing(10, 1.1f);
        descTv.setPadding(0, 0, 0, 48);
        card.addView(descTv);

        // Back to WABI Button
        Button backBtn = new Button(this);
        backBtn.setText("WABI ga Qaytish");
        backBtn.setTextColor(Color.parseColor("#12100E"));
        backBtn.setTextSize(16);
        backBtn.setTypeface(Typeface.DEFAULT_BOLD);

        GradientDrawable btnBg = new GradientDrawable();
        btnBg.setColor(Color.parseColor("#D4B996")); // Sand Gold
        btnBg.setCornerRadius(40f);
        backBtn.setBackground(btnBg);
        backBtn.setPadding(48, 30, 48, 30);

        backBtn.setOnClickListener(v -> {
            Intent mainIntent = new Intent(this, MainActivity.class);
            mainIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
            startActivity(mainIntent);
            finish();
        });
        card.addView(backBtn);

        root.addView(card);
        setContentView(root);
    }

    @Override
    public void onBackPressed() {
        // Return to home screen when back is pressed
        Intent homeIntent = new Intent(Intent.ACTION_MAIN);
        homeIntent.addCategory(Intent.CATEGORY_HOME);
        homeIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        startActivity(homeIntent);
        finish();
    }
}
