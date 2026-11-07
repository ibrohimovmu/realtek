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
const targetDir = path.resolve(__dirname, '../android/app/src/main/assets/public');

console.log(`Syncing NOVA Zero-UI bundle from ${srcDir} to ${targetDir}...`);
if (fs.existsSync(targetDir)) {
  fs.rmSync(targetDir, { recursive: true, force: true });
}
fs.mkdirSync(targetDir, { recursive: true });
copyRecursiveSync(srcDir, targetDir);
console.log('✓ Successfully synced NOVA Zero-UI assets into Android APK bundle!');
