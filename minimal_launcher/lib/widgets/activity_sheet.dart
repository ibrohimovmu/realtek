import 'package:flutter/material.dart';
import '../services/launcher_store.dart';

class ActivitySheet extends StatelessWidget {
  final LauncherStore store;

  const ActivitySheet({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final history = store.activityLog;
        final recent = store.recentApps;

        return Container(
          height: MediaQuery.of(context).size.height * 0.78,
          decoration: BoxDecoration(
            color: const Color(0xFF0E1D21),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: const Color(0xFF677E8A).withValues(alpha: 0.30),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF677E8A).withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FAOLLIK VA KIRILGAN ILOVALAR TARIXI',
                            style: TextStyle(
                              color: Color(0xFFABAFB5),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.3,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Qaysi ilovalarga qachon va necha marta kirilganligi hisoboti',
                            style: TextStyle(
                              color: Color(0xFF677E8A),
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                      if (history.isNotEmpty)
                        TextButton(
                          onPressed: store.clearActivityHistory,
                          child: const Text(
                            'Tozalash',
                            style: TextStyle(
                              color: Color(0xFFE0B4B2),
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Most Used Apps Bar
                  if (recent.isNotEmpty) ...[
                    const Text(
                      'ENG KO\'P ISHLATILGANLAR',
                      style: TextStyle(
                        color: Color(0xFF677E8A),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 64,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: recent.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, idx) {
                          final app = recent[idx];
                          final count = store.launchCountOf(app.packageName);
                          return GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              store.launchApp(app);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF122E34),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFF677E8A)
                                      .withValues(alpha: 0.25),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    app.name,
                                    style: const TextStyle(
                                      color: Color(0xFFABAFB5),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    '$count marta kirilgan',
                                    style: const TextStyle(
                                      color: Color(0xFFE0B4B2),
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  const Text(
                    'XRONOLOGIK JURNAL',
                    style: TextStyle(
                      color: Color(0xFF677E8A),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Expanded(
                    child: history.isEmpty
                        ? const Center(
                            child: Text(
                              'Hozircha kirilgan ilovalar tarixi bo\'sh',
                              style: TextStyle(
                                color: Color(0xFF677E8A),
                                fontSize: 13,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: history.length,
                            separatorBuilder: (_, _) =>
                                const Divider(color: Color(0xFF122E34)),
                            itemBuilder: (context, idx) {
                              final entry = history[idx];
                              final t = entry.timestamp;
                              final timeStr =
                                  '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF122E34),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.north_east_rounded,
                                    color: Color(0xFFABAFB5),
                                    size: 16,
                                  ),
                                ),
                                title: Text(
                                  entry.appName,
                                  style: const TextStyle(
                                    color: Color(0xFFABAFB5),
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  entry.packageName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF677E8A),
                                    fontSize: 11,
                                  ),
                                ),
                                trailing: Text(
                                  timeStr,
                                  style: const TextStyle(
                                    color: Color(0xFFE0B4B2),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
