import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/live_list.dart';
import '../../services/live_list_storage.dart';
import '../scaletta_screen.dart';
import '../lettura_spartito_screen.dart';
import '../live/live_screen.dart'; // ⭐ AGGIUNTO IMPORT NECESSARIO

class LiveListDetailScreen extends StatefulWidget {
  final LiveList list;

  const LiveListDetailScreen({super.key, required this.list});

  @override
  State<LiveListDetailScreen> createState() => _LiveListDetailScreenState();
}

class _LiveListDetailScreenState extends State<LiveListDetailScreen> {
  final LiveListStorage storage = LiveListStorage();

  Future<void> _apriSpartito(String id) async {
    final parts = id.split("|");
    final titolo = parts[0];
    final artista = parts.length > 1 ? parts[1] : "";

    final prefs = await SharedPreferences.getInstance();
    final listaScaletta = prefs.getStringList("scaletta") ?? [];

    Map<String, dynamic>? branoTrovato;

    for (final item in listaScaletta) {
      final map = jsonDecode(item);
      if (map["titolo"] == titolo && map["artista"] == artista) {
        branoTrovato = map;
        break;
      }
    }

    if (branoTrovato == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Brano non trovato nella scaletta")),
      );
      return;
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LetturaSpartitoScreen(
          titolo: branoTrovato!["titolo"] ?? "",
          artista: branoTrovato!["artista"] ?? "",
          testoCompleto: branoTrovato!["testoCompleto"] ?? "",
          trasposizione: branoTrovato!["trasposizione"] ?? 0,
        ),
      ),
    );
  }

  Future<void> _rimuoviDaLiveList(String id) async {
    widget.list.songIds.remove(id);

    final all = await storage.loadLists();
    final index = all.indexWhere((l) => l.id == widget.list.id);
    if (index != -1) {
      all[index] = widget.list;
      await storage.saveLists(all);
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF303030),

      body: Column(
        children: [
          // ⭐ HEADER
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
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LiveScreen(), // ⭐ MODIFICA APPLICATA
                          ),
                        );
                      },
                    ),

                    Text(
                      widget.list.name.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),

                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),

          // ⭐ LISTA BRANI LIVE
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.only(top: 10),

              buildDefaultDragHandles: false,

              proxyDecorator: (child, index, animation) {
                return Material(
                  color: Colors.transparent,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF3A3A3A),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: child,
                  ),
                );
              },

              itemCount: widget.list.songIds.length,

              onReorder: (oldIndex, newIndex) async {
                if (newIndex > oldIndex) newIndex--;

                final items = widget.list.songIds;
                final item = items.removeAt(oldIndex);
                items.insert(newIndex, item);

                final all = await storage.loadLists();
                final index = all.indexWhere((l) => l.id == widget.list.id);
                all[index] = widget.list;
                await storage.saveLists(all);

                setState(() {});
              },

              itemBuilder: (_, index) {
                final id = widget.list.songIds[index];

                return Dismissible(
                  key: ValueKey("dismiss-$id"),
                  direction: DismissDirection.endToStart,

                  background: Container(
                    color: Colors.red,
                    padding: const EdgeInsets.only(right: 20),
                    alignment: Alignment.centerRight,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(Icons.delete, color: Colors.white, size: 28),
                        SizedBox(width: 8),
                        Text(
                          "Rimuovi",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      ],
                    ),
                  ),

                  confirmDismiss: (_) async {
                    await _rimuoviDaLiveList(id);
                    return true;
                  },

                  child: ReorderableDelayedDragStartListener(
                    index: index,

                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),

                      leading: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.amber,
                          shape: BoxShape.circle,
                        ),
                      ),

                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            id.split("|")[0],
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            id.split("|").length > 1 ? id.split("|")[1] : "",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),

                      trailing: null,

                      onTap: () => _apriSpartito(id),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
