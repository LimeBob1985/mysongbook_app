import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:bonsoir/bonsoir.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

class WebService {
  static final WebService _instance = WebService._internal();
  factory WebService() => _instance;
  WebService._internal();

  HttpServer? _server;
  BonsoirBroadcast? _broadcast;

  // Funzione che verrà chiamata quando riceviamo un brano
  Function(Map<String, dynamic>)? onSongReceived;

  /// Avvia il server e il servizio di scoperta (Bonjour)
  Future<void> start(String deviceName) async {
    // 1. Configura il Router per ricevere i dati
    final router = Router();

    router.post('/receive-song', (Request request) async {
      try {
        final payload = await request.readAsString();
        final Map<String, dynamic> songData = jsonDecode(payload);
        
        if (onSongReceived != null) {
          onSongReceived!(songData);
        }
        
        return Response.ok('Brano ricevuto con successo');
      } catch (e) {
        return Response.internalServerError(body: 'Errore nel parsing del brano');
      }
    });

    // 2. Avvia il Server HTTP su una porta libera (0 indica porta casuale disponibile)
    _server = await io.serve(router, InternetAddress.anyIPv4, 0);
    final int port = _server!.port;
    print('Server MySongBook in ascolto sulla porta $port');

    // 3. Avvia Bonsoir per annunciare il servizio sulla rete locale
    // Usiamo lo stesso tipo '_mysongbook._tcp' definito nella scaletta
    final bonsoirService = BonsoirService(
      name: deviceName,
      type: '_mysongbook._tcp',
      port: port,
    );

    _broadcast = BonsoirBroadcast(service: bonsoirService);
    await _broadcast!.ready;
    await _broadcast!.start();
    print('Annuncio Wi-Fi attivo: $deviceName su porta $port');
  }

  /// Invia un brano a un altro dispositivo
  Future<bool> sendSong(String host, int port, Map<String, dynamic> song) async {
    try {
      final client = HttpClient();
      // Impostiamo un timeout per non far bloccare l'app se il dispositivo non risponde
      client.connectionTimeout = const Duration(seconds: 5);
      
      final request = await client.post(host, port, '/receive-song');
      request.headers.contentType = ContentType.json;
      
      // Convertiamo la mappa del brano in stringa JSON
      final jsonBody = jsonEncode(song);
      request.add(utf8.encode(jsonBody));
      
      final response = await request.close();
      
      if (response.statusCode == 200) {
        print('Invio completato con successo a $host');
        return true;
      } else {
        print('Il server ha risposto con errore: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Errore durante l\'invio Wi-Fi: $e');
      return false;
    }
  }

  /// Ferma tutto quando l'app viene chiusa
  Future<void> stop() async {
    await _broadcast?.stop();
    await _server?.close();
    print('Servizi Web chiusi correttamente');
  }
}