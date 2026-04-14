import 'package:flutter/material.dart';
import '../../services/live_list_storage.dart';
import '../../models/live_list.dart';
import 'live_list_detail_screen.dart';
import '../crea_spartito_screen.dart';
import '../scaletta_screen.dart';
import '../bozze_screen.dart';

class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  final LiveListStorage storage = LiveListStorage();
  List<LiveList> lists = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    lists = await storage.loadLists();
    lists.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (mounted) setState(() {});
  }

  // ⭐ Navigazione verso SINISTRA (per tornare a Bozze, Scaletta, Crea)
  void _navBack(Widget screen) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => screen,
        transitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween(begin: const Offset(-1, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );
  }

  Future<void> _createNewList() async {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Nuova LiveList"),
        content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: "Nome cartella")),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Annulla")),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              lists.add(LiveList(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: name,
                  songIds: []));
              await storage.saveLists(lists);
              _load();
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Crea"),
          ),
        ],
      ),
    );
  }

  void _rinominaLista(LiveList list) {
    final controller = TextEditingController(text: list.name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Rinomina cartella"),
        content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: "Nuovo nome")),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Annulla")),
          TextButton(
            onPressed: () async {
              final nuovoNome = controller.text.trim();
              if (nuovoNome.isEmpty) return;
              final index = lists.indexWhere((l) => l.id == list.id);
              if (index != -1) {
                lists[index] = list.copyWith(name: nuovoNome);
                lists.sort((a, b) =>
                    a.name.toLowerCase().compareTo(b.name.toLowerCase()));
                await storage.saveLists(lists);
              }
              if (mounted) Navigator.pop(context);
              setState(() {});
            },
            child: const Text("Salva"),
          ),
        ],
      ),
    );
  }

  Future<void> _eliminaLista(LiveList list) async {
    lists.remove(list);
    await storage.saveLists(lists);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF303030),
      body: Column(
        children: [
          Container(
            color: Colors.black,
            child: SafeArea(
                bottom: false,
                child: Container(
                    height: 70,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SizedBox(width: 48),
                          const Text("LIVE",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                          IconButton(
                              icon: const Icon(Icons.add,
                                  color: Colors.white, size: 28),
                              onPressed: _createNewList),
                        ]))),
          ),
          Container(
            height: 50,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _menuBtn("crea spartito", () => _navBack(const CreaSpartitoScreen())),
              const SizedBox(width: 24),
              _menuBtn("scaletta", () => _navBack(const ScalettaScreen())),
              const SizedBox(width: 24),
              _menuBtn("bozze", () => _navBack(const BozzeScreen())),
              const SizedBox(width: 24),
              const Text("live",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
            ]),
          ),
          Expanded(
            child: lists.isEmpty
                ? const Center(
                    child: Text("Nessuna LiveList.\nCrea la tua prima scaletta live!",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 16)))
                : ListView.builder(
                    itemCount: lists.length,
                    itemBuilder: (_, i) {
                      final list = lists[i];
                      return Dismissible(
                        key: ValueKey(list.id),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (_) async {
                          await _eliminaLista(list);
                          return true;
                        },
                        background: Container(
                            color: Colors.red,
                            padding: const EdgeInsets.only(right: 20),
                            alignment: Alignment.centerRight,
                            child: const Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Icon(Icons.delete, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text("Elimina",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold))
                                ])),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          leading: const Icon(Icons.folder,
                              color: Color(0xFF64B5F6), size: 32),
                          title: Text(list.name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                          subtitle: Text("${list.songIds.length} brani",
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13)),
                          onTap: () => Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (_, __, ___) =>
                                  LiveListDetailScreen(list: list),
                              transitionDuration:
                                  const Duration(milliseconds: 200),
                              transitionsBuilder: (_, anim, __, child) =>
                                  FadeTransition(opacity: anim, child: child),
                            ),
                          ).then((_) => _load()),
                          onLongPress: () => _rinominaLista(list),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _menuBtn(String label, VoidCallback onTap) => GestureDetector(
      onTap: onTap,
      child: Text(label,
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3), fontSize: 14)));
}