const fs = require('fs');
const path = require('path');

function copyRecursiveSync(src, dest) {
  const exists = fs.existsSync(src);
  const stats = exists && fs.statSync(src);
  const isDirectory = exists && stats.isDirectory();
  if (isDirectory) {
    if (!fs.existsSync(dest)) {
      fs.mkdirSync(dest, { recursive: true });
    }
    fs.readdirSync(src).forEach((childItemName) => {
      copyRecursiveSync(path.join(src, childItemName), path.join(dest, childItemName));
    });
  } else {
    fs.copyFileSync(src, dest);
  }
}

const srcDir = path.resolve(__dirname, '../www');
const targetPublic = path.resolve(__dirname, '../android/app/src/main/assets/public');
const targetRoot = path.resolve(__dirname, '../android/app/src/main/assets');

console.log(`Syncing AURA bundle from ${srcDir} to Android assets...`);
copyRecursiveSync(srcDir, targetPublic);
copyRecursiveSync(srcDir, targetRoot);
console.log('✓ Successfully synced AURA assets into Android APK bundle!');
