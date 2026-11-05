import 'package:flutter/material.dart';

enum Rarity {
  common('Oddiy', Color(0xFF9E9E9E)),
  rare('Nodir', Color(0xFF29B6F6)),
  epic('Epik', Color(0xFFAB47BC)),
  legendary('Afsonaviy', Color(0xFFFFB300));

  final String label;
  final Color color;
  const Rarity(this.label, this.color);
}

class Weapon {
  final String id;
  final String name;
  final int dmg;
  final int mag;
  final int price;
  final IconData icon;
  final Color color;
  final int fireRateMs;
  final bool isAuto;
  final double recoil;
  final int reloadMs;
  final String soundAsset;
  final Rarity rarity;

  const Weapon({
    required this.id,
    required this.name,
    required this.dmg,
    required this.mag,
    required this.price,
    required this.icon,
    required this.color,
    required this.fireRateMs,
    required this.isAuto,
    required this.recoil,
    required this.reloadMs,
    required this.soundAsset,
    required this.rarity,
  });
}

const kWeapons = [
  Weapon(
    id: 'pistol',
    name: 'P92 Pistol',
    dmg: 25,
    mag: 12,
    price: 0,
    icon: Icons.gps_fixed,
    color: Colors.grey,
    fireRateMs: 400,
    isAuto: false,
    recoil: 4.0,
    reloadMs: 1400,
    soundAsset: 'audio/pistol.wav',
    rarity: Rarity.common,
  ),
  Weapon(
    id: 'smg',
    name: 'UMP45 SMG',
    dmg: 18,
    mag: 30,
    price: 300,
    icon: Icons.bolt,
    color: Colors.cyan,
    fireRateMs: 130,
    isAuto: true,
    recoil: 6.0,
    reloadMs: 2000,
    soundAsset: 'audio/smg.wav',
    rarity: Rarity.rare,
  ),
  Weapon(
    id: 'ar',
    name: 'M416 Rifle',
    dmg: 26,
    mag: 30,
    price: 800,
    icon: Icons.local_fire_department,
    color: Colors.orange,
    fireRateMs: 160,
    isAuto: true,
    recoil: 8.5,
    reloadMs: 2200,
    soundAsset: 'audio/ar.wav',
    rarity: Rarity.epic,
  ),
  Weapon(
    id: 'shotgun',
    name: 'S12K Shotgun',
    dmg: 65,
    mag: 8,
    price: 1200,
    icon: Icons.blur_on,
    color: Colors.redAccent,
    fireRateMs: 700,
    isAuto: false,
    recoil: 14.0,
    reloadMs: 2800,
    soundAsset: 'audio/shotgun.wav',
    rarity: Rarity.epic,
  ),
  Weapon(
    id: 'sniper',
    name: 'AWM Sniper',
    dmg: 110,
    mag: 5,
    price: 2000,
    icon: Icons.my_location,
    color: Colors.amber,
    fireRateMs: 1300,
    isAuto: false,
    recoil: 22.0,
    reloadMs: 3400,
    soundAsset: 'audio/sniper.wav',
    rarity: Rarity.legendary,
  ),
];

Weapon weaponOf(String id) =>
    kWeapons.firstWhere((w) => w.id == id, orElse: () => kWeapons.first);
