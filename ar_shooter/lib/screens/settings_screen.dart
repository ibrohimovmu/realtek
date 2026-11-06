import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/server_client.dart';
import '../services/store.dart';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _serverController = TextEditingController();
  bool? _isServerOnline;
  bool _isCheckingServer = false;

  @override
  void initState() {
    super.initState();
    _serverController.text = Store.i.serverUrl;
  }

  @override
  void dispose() {
    _serverController.dispose();
    super.dispose();
  }

  Future<void> _checkServer() async {
    setState(() => _isCheckingServer = true);
    final isUp = await ServerClient.i.checkHealth();
    if (mounted) {
      setState(() {
        _isServerOnline = isUp;
        _isCheckingServer = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isUp ? 'Server faol va ishlayapti (Online)!' : 'Server bilan aloqa yo\'q (Oflayn)',
          ),
          backgroundColor: isUp ? kGreen : kOrange,
        ),
      );
    }
  }

  void _showRenameDialog() {
    final c = TextEditingController(text: Store.i.name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kCard,
        title: const Text('Taxallusni yangilash'),
        content: TextField(
          controller: c,
          maxLength: 16,
          decoration: const InputDecoration(hintText: 'Yangi taxallus'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            onPressed: () {
              if (c.text.trim().isNotEmpty) {
                Store.i.setName(c.text.trim());
                setState(() {});
              }
              Navigator.pop(context);
            },
            child: const Text('Saqlash'),
          ),
        ],
      ),
    );
  }

  void _exportJson() {
    final jsonStr = Store.i.exportToJson();
    Clipboard.setData(ClipboardData(text: jsonStr));

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kCard,
        title: const Text('JSON Eksport Qilindi'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Barcha ma\'lumotlar buferga (clipboard) nusxalandi. Uni xavfsiz joyda saqlab qo\'yishingiz mumkin:',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  jsonStr,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Yopish'),
          ),
        ],
      ),
    );
  }

  void _showImportDialog() {
    final c = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kCard,
        title: const Text('JSON Zaxirani Qayta Tiklash'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Avval eksport qilingan JSON matnini shu yerga qo\'ying:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: c,
              maxLines: 6,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              decoration: const InputDecoration(
                hintText: '{"schema_version": 3, ...}',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            onPressed: () {
              final text = c.text.trim();
              if (text.isNotEmpty) {
                final ok = Store.i.importFromJson(text);
                Navigator.pop(context);
                if (ok) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profil muvaffaqiyatli tiklandi!')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Xatolik: JSON formati noto\'g\'ri!')),
                  );
                }
              }
            },
            child: const Text('Tiklash'),
          ),
        ],
      ),
    );
  }

  void _confirmReset() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kCard,
        title: const Text('Taraqqiyotni o\'chirish?'),
        content: const Text(
          'Barcha qurollar, tangalar, daraja va statistika qayta nollanadi. Bunga aminmisiz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            onPressed: () {
              Store.i.resetProgress();
              setState(() {});
              Navigator.pop(context);
            },
            child: const Text('Ha, hammasini tozalash'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.i,
      builder: (context, _) {
        final s = Store.i;
        return Scaffold(
          backgroundColor: kBg,
          appBar: AppBar(
            backgroundColor: kBg,
            elevation: 0,
            title: const Text('Sozlamalar', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              // Callsign / Account section
              const Text('Profil', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              card(
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: kPurple,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Mintaqa: ${s.region} • ${s.playStyle}'),
                  trailing: TextButton(
                    onPressed: _showRenameDialog,
                    child: const Text('O\'zgartirish'),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Game Settings Section
              const Text('O\'yin & Sensorlar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              card(
                Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: kPurple,
                      title: const Text('Ovoz effektlari (Audio)'),
                      subtitle: const Text('Qurollar, portlash va zarba tovushlari'),
                      value: s.soundEnabled,
                      onChanged: (v) => s.setSettings(sound: v),
                    ),
                    const Divider(color: Colors.white12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: kPurple,
                      title: const Text('Vibratsiya & Haptics'),
                      subtitle: const Text('Zarba va o\'q otish tebranishi'),
                      value: s.vibrationEnabled,
                      onChanged: (v) => s.setSettings(vibration: v),
                    ),
                    const Divider(color: Colors.white12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: kPurple,
                      title: const Text('GPS & Kompas Almashish'),
                      subtitle: const Text('Xonadagi do\'stlar bilan uzoq masofali kompas va yo\'nalish'),
                      value: s.gpsSharingEnabled,
                      onChanged: (v) {
                        s.gpsSharingEnabled = v;
                        s.save();
                      },
                    ),
                    const Divider(color: Colors.white12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: kPurple,
                      title: const Text('FPS & Taktik Debug Overlay'),
                      subtitle: const Text('Kamera kadr tezligi va ML kechikishi ko\'rsatkichi'),
                      value: s.debugOverlayEnabled,
                      onChanged: (_) => s.toggleDebugOverlay(),
                    ),
                    const Divider(color: Colors.white12),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Nishon Sezgirligi (Sensitivity):', style: TextStyle(fontWeight: FontWeight.w600)),
                        Text('${s.sensitivity.toStringAsFixed(1)}x', style: const TextStyle(color: kPurple, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Slider(
                      value: s.sensitivity,
                      min: 0.5,
                      max: 2.0,
                      divisions: 15,
                      activeColor: kPurple,
                      onChanged: (v) => s.setSettings(sens: v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Server & Language
              const Text('Tarmoq & Til', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              card(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Server Manzili (Online Hub):', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _serverController,
                      decoration: InputDecoration(
                        hintText: 'http://192.168.1.100:7860',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.check, color: kPurple),
                          onPressed: () {
                            s.serverUrl = _serverController.text.trim();
                            s.save();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Server manzili saqlandi!')),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        FilledButton.tonal(
                          onPressed: _isCheckingServer ? null : _checkServer,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(120, 36),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: _isCheckingServer
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Aloqani Tekshirish', style: TextStyle(fontSize: 11)),
                        ),
                        const SizedBox(width: 10),
                        if (_isServerOnline != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (_isServerOnline! ? kGreen : kOrange).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _isServerOnline! ? kGreen : kOrange),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _isServerOnline! ? kGreen : kOrange,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _isServerOnline! ? 'Online' : 'Offline',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _isServerOnline! ? kGreen : kOrange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Interfeys Tili:', style: TextStyle(fontWeight: FontWeight.w600)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: kPurple.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: kPurple),
                          ),
                          child: const Text('O\'zbekcha (Lotin)', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Backup & Migration
              const Text('Zaxira & Eksport (JSON)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              card(
                Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.upload_file, color: kPurple),
                      title: const Text('JSON Eksport'),
                      subtitle: const Text('Barcha qurollar va yutuqlarni matn sifatida nusxalash'),
                      trailing: FilledButton.tonal(
                        onPressed: _exportJson,
                        child: const Text('Eksport'),
                      ),
                    ),
                    const Divider(color: Colors.white12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.download, color: kGreen),
                      title: const Text('JSON Import'),
                      subtitle: const Text('Eksport qilingan JSON zaxirasidan tiklash'),
                      trailing: FilledButton.tonal(
                        onPressed: _showImportDialog,
                        child: const Text('Import'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Danger Zone: Reset Progress
              OutlinedButton.icon(
                onPressed: _confirmReset,
                icon: const Icon(Icons.delete_forever, size: 20, color: kRed),
                label: const Text('Taraqqiyotni Tozalash (Reset)', style: TextStyle(color: kRed)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: kRed),
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}
