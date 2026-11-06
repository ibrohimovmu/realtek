import 'package:flutter/material.dart';

class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

const List<Achievement> kAchievements = [
  Achievement(
    id: 'first_blood',
    title: 'Birinchi Qon',
    description: 'Birinchi dushmanni yengish',
    icon: Icons.flash_on,
    color: Color(0xFFFF2A4D),
  ),
  Achievement(
    id: 'marksman',
    title: 'Merkut Mergan',
    description: '10 ta dushmanni aniq otib yengish',
    icon: Icons.track_changes,
    color: Color(0xFFFF8A00),
  ),
  Achievement(
    id: 'reaper',
    title: 'Ajal Mashinasi',
    description: '50 ta g\'alabaga erishish',
    icon: Icons.dangerous,
    color: Color(0xFFE02424),
  ),
  Achievement(
    id: 'silver_rank',
    title: 'Kumush Jangchi',
    description: '500 XP to\'plab Kumush ligaga chiqish',
    icon: Icons.military_tech,
    color: Color(0xFF9E9E9E),
  ),
  Achievement(
    id: 'gold_rank',
    title: 'Oltin Elita',
    description: '1500 XP to\'plab Oltin ligaga ko\'tarilish',
    icon: Icons.shield,
    color: Color(0xFFFFD700),
  ),
  Achievement(
    id: 'diamond_rank',
    title: 'Olmos Afsona',
    description: '3500 XP bilan Olmos darajaga erishish',
    icon: Icons.workspace_premium,
    color: Color(0xFF22D3EE),
  ),
  Achievement(
    id: 'armorer',
    title: 'Arsenal Ustasi',
    description: '3 ta har xil qurolga ega bo\'lish',
    icon: Icons.handyman,
    color: Color(0xFF6C47FF),
  ),
  Achievement(
    id: 'dedicated',
    title: 'Sodiq Qatnashchi',
    description: '5 kun ketma-ket o\'yinga kirish bonusi',
    icon: Icons.local_fire_department,
    color: Color(0xFFFF8A00),
  ),
  Achievement(
    id: 'bomb_expert',
    title: 'Saper Mutaxassis',
    description: 'C4 bombasini o\'rnatish yoki zararsizlantirish',
    icon: Icons.timer,
    color: Color(0xFFF59E0B),
  ),
  Achievement(
    id: 'medic',
    title: 'Maydon Shifokori',
    description: 'Aptechka va bog\'lamlardan foydalanish',
    icon: Icons.healing,
    color: Color(0xFF2EE59D),
  ),
];
